class Api::V1::ConversationsController < ApplicationController
  before_action :set_conversation,
                only: [ :update, :read ]

  before_action :ensure_participant,
                only: [ :update, :read ]

  def index
    conversations = current_user.conversations
                                .includes(
                                  :participants,
                                  :messages
                                )

    filter = params[:filter].presence || "all"
    search = params[:search].to_s.strip

    case filter
    when "unread"
      conversations = conversations.where(
        id: current_user.conversation_participants
                        .where.not(last_read_message_id: nil)
                        .select(:conversation_id)
      )
    when "favorite"
      conversations = current_user.conversation_participants
                                  .where(is_favorite: true)
                                  .includes(:conversation)
                                  .map(&:conversation)
    end

    if search.present?
      conversations = conversations.select do |conversation|
        title_for(conversation)
          .downcase
          .include?(search.downcase)
      end
    end

    conversations = conversations.sort_by do |conversation|
      conversation.messages.maximum(:created_at) || conversation.created_at
    end.reverse

    limit = [ [ params[:limit].to_i, 1 ].max, 100 ].min
    limit = 30 if params[:limit].blank?

    items = conversations.first(limit)

    render json: {
      items: items.map {
        |conversation|
        serialize_conversation(conversation)
      },
      nextCursor: nil
    }
  end

  def create
    kind = params[:kind].presence || "direct"
    participant_ids = Array(params[:participantIds])
      .map(&:to_s)
      .reject(&:blank?)
      .push(current_user.id.to_s)
      .uniq

    unless %w[direct group].include?(kind)
      return render_error("INVALID_KIND", "Jenis conversation tidak valid", :unprocessable_entity)
    end

    if kind == "direct" && participant_ids.length != 2
      return render_error("INVALID_PARTICIPANTS", "Direct conversation harus memiliki 2 peserta", :unprocessable_entity)
    end

    users = User.where(id: participant_ids)
    if users.count != participant_ids.length
      return render_error("USER_NOT_FOUND", "Salah satu user tidak ditemukan", :unprocessable_entity)
    end

    if kind == "direct"
      existing = Conversation.joins(:conversation_participants)
        .where(kind: kind, conversation_participants: { user_id: participant_ids })
        .group("conversations.id")
        .having("COUNT(DISTINCT conversation_participants.user_id) = ?", participant_ids.length)
        .first
      return render json: serialize_conversation(existing) if existing
    end

    conversation = Conversation.transaction do
      record = Conversation.create!(
        kind: kind,
        title: params[:title].presence,
        avatar_url: params[:avatarUrl].presence
      )
      participant_ids.each do |user_id|
        record.conversation_participants.create!(user_id: user_id)
      end
      record
    end

    conversation.participants.each do |participant|
      ActionCable.server.broadcast(
        "user_#{participant.id}",
        {
          type: "conversation.created",
          conversationId: conversation.id
        }
      )
    end

    render json: serialize_conversation(conversation), status: :created
  rescue ActiveRecord::RecordInvalid => error
    render_error("VALIDATION_ERROR", error.record.errors.full_messages.join(", "), :unprocessable_entity)
  end

  def update
    participant = current_user
      .conversation_participants
      .find_by(conversation_id: @conversation.id)

    if params.key?(:isFavorite)
      participant.update!(
        is_favorite: ActiveModel::Type::Boolean.new.cast(
          params[:isFavorite]
        )
      )
    end

    render json: serialize_conversation(@conversation)
  end

  def read
    message_id = params[:lastReadMessageId]

    message = @conversation.messages.find_by(id: message_id)

    unless message
      return render_error(
        "MESSAGE_NOT_FOUND",
        "Message tidak ditemukan",
        :not_found
      )
    end

    participant = current_user
      .conversation_participants
      .find_by(conversation_id: @conversation.id)

    participant.update!(
      last_read_message_id: message.id
    )

    ActionCable.server.broadcast(
      "conversation_#{@conversation.id}",
      {
        type: "conversation.read",
        conversationId: @conversation.id,
        userId: current_user.id,
        lastReadMessageId: message.id
      }
    )

    render json: {
      success: true,
      conversationId: @conversation.id,
      lastReadMessageId: message.id
    }
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:id])

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

    return if participant

    render_error(
      "FORBIDDEN",
      "Anda bukan anggota conversation ini",
      :forbidden
    )
  end

  def title_for(conversation)
    return conversation.title if conversation.title.present?

    other = conversation.participants
                        .where.not(id: current_user.id)
                        .first

    other&.name || "Conversation"
  end

  def serialize_conversation(conversation)
    participant = conversation
      .conversation_participants
      .find_by(user_id: current_user.id)

    last_message = conversation
      .messages
      .order(created_at: :desc)
      .first

    other_participant = conversation.kind == "direct" ? conversation.participants.where.not(id: current_user.id).first : nil

    unread_count = unread_count(
      conversation,
      participant
    )

    {
      id: conversation.id,
      kind: conversation.kind,
      title: title_for(conversation),
      avatarUrl: conversation.avatar_url || serialized_avatar_url(other_participant),
      participantCount: conversation.participants.count,
      isFavorite: participant&.is_favorite || false,
      unreadCount: unread_count,
      lastMessage: last_message && {
        id: last_message.id,
        text: last_message.text,
        createdAt: last_message.created_at.iso8601(3),
        senderId: last_message.sender_id
      }
    }
  end

  def unread_count(conversation, participant)
    return 0 unless participant

    messages = conversation.messages

    if participant.last_read_message_id.blank?
      return messages.where.not(
        sender_id: current_user.id
      ).count
    end

    last_read = messages.find_by(
      id: participant.last_read_message_id
    )

    return 0 unless last_read

    messages
      .where("created_at > ?", last_read.created_at)
      .where.not(sender_id: current_user.id)
      .count
  end
end
