class Api::V1::MessagesController < ApplicationController
  before_action :set_conversation
  before_action :ensure_participant

  def index
    limit = [ [ params[:limit].to_i, 1 ].max, 100 ].min
    limit = 50 if params[:limit].blank?

    messages = @conversation.messages
                 .includes(:sender)
                             .order(created_at: :desc, id: :desc)
    messages = messages.where("created_at > ?", @participant.cleared_at) if @participant&.cleared_at

    search = params[:search].to_s.strip
    if search.present?
      messages = messages.where(
        "text ILIKE ?",
        "%#{Message.sanitize_sql_like(search)}%"
      )
    end

    if params[:before].present?
      cursor_message = @conversation.messages.find_by(
        id: params[:before]
      )

      if cursor_message
        messages = messages.where(
          "created_at < ? OR (created_at = ? AND id < ?)",
          cursor_message.created_at,
          cursor_message.created_at,
          cursor_message.id
        )
      end
    end

    records = messages.limit(limit + 1).to_a

    has_more = records.length > limit
    records = records.first(limit)

    records.reverse!

    render json: {
      items: records.map { |message|
        serialize_message(message)
      },
      nextCursor: has_more ? records.first&.id : nil
    }
  end

  def create
    client_message_id =
      params[:clientMessageId].presence ||
      request.headers["Idempotency-Key"].presence

    text = params[:text].to_s.strip

    if client_message_id.blank?
      return render_error(
        "CLIENT_MESSAGE_ID_REQUIRED",
        "clientMessageId wajib diisi",
        :unprocessable_entity
      )
    end

    uploads = Array(params[:attachments]).reject(&:blank?)
    if text.blank? && uploads.empty?
      return render_error(
        "MESSAGE_EMPTY",
        "Pesan tidak boleh kosong",
        :unprocessable_entity
      )
    end

    if text.length > 5000
      return render_error(
        "MESSAGE_TOO_LONG",
        "Pesan maksimal 5000 karakter",
        :unprocessable_entity
      )
    end

    existing = @conversation.messages.find_by(
      client_message_id: client_message_id
    )

    if existing
      return render json: serialize_message(existing)
    end

    message = @conversation.messages.build(
      sender: current_user,
      client_message_id: client_message_id,
      text: text
    )
    message.attachments.attach(uploads) if uploads.any?
    message.save!

    @conversation.conversation_participants
           .where.not(hidden_at: nil)
           .update_all(hidden_at: nil, updated_at: Time.current)

    payload = {
      type: "message.created",
      conversationId: @conversation.id,
      message: serialize_message(message)
    }

    ActionCable.server.broadcast(
      "conversation_#{@conversation.id}",
      payload
    )

    @conversation.participants.each do |participant|
      ActionCable.server.broadcast(
        "user_#{participant.id}",
        { type: "conversation.created", conversationId: @conversation.id }
      )
    end

    render json: serialize_message(message),
           status: :created

  rescue ActiveRecord::RecordInvalid => error
    render_error("VALIDATION_ERROR", error.record.errors.full_messages.join(", "), :unprocessable_entity)
  rescue ActiveRecord::RecordNotUnique
    existing = @conversation.messages.find_by!(
      client_message_id: client_message_id
    )

    render json: serialize_message(existing)
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id])

    unless @conversation
      render_error(
        "CONVERSATION_NOT_FOUND",
        "Conversation tidak ditemukan",
        :not_found
      )
    end
  end

  def ensure_participant
    return unless @conversation

    participant = current_user
      .conversation_participants
      .find_by(conversation_id: @conversation.id)

    if participant
      @participant = participant
      return
    end

    render_error(
      "FORBIDDEN",
      "Anda bukan anggota conversation ini",
      :forbidden
    )
  end

  def serialize_message(message)
    {
      id: message.id,
      conversationId: message.conversation_id,
      senderId: message.sender_id,
      senderName: message.sender.name,
      text: message.text,
      createdAt: message.created_at.iso8601(3),
      status: "sent",
      attachments: message.attachments.map do |attachment|
        {
          id: attachment.id,
          filename: attachment.filename.to_s,
          contentType: attachment.content_type,
          byteSize: attachment.byte_size,
          url: serialized_blob_url(attachment)
        }
      end
    }
  end
end
