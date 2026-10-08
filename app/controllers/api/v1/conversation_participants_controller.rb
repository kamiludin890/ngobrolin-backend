class Api::V1::ConversationParticipantsController < ApplicationController
  before_action :set_conversation
  before_action :ensure_group
  before_action :ensure_participant

  def create
    user = User.find_by(id: params[:userId])
    return render_error("USER_NOT_FOUND", "User tidak ditemukan", :not_found) unless user

    participant = @conversation.conversation_participants.find_or_initialize_by(user: user)
    was_new = participant.new_record?
    participant.update!(hidden_at: nil)

    broadcast_to_members("conversation.updated")
    head(was_new ? :created : :no_content)
  rescue ActiveRecord::RecordInvalid => error
    render_error("VALIDATION_ERROR", error.record.errors.full_messages.join(", "), :unprocessable_entity)
  end

  def destroy
    participant = @conversation.conversation_participants.find_by(user_id: params[:id])
    return render_error("USER_NOT_FOUND", "Anggota tidak ditemukan", :not_found) unless participant
    return render_error("INVALID_PARTICIPANT", "Anda tidak dapat mengeluarkan diri sendiri", :unprocessable_entity) if participant.user_id == current_user.id
    return render_error("MINIMUM_MEMBERS", "Grup harus memiliki minimal 2 anggota", :unprocessable_entity) if @conversation.conversation_participants.count <= 2

    removed_user_id = participant.user_id
    participant.destroy!
    broadcast_to_members("conversation.updated")
    ActionCable.server.broadcast(
      "user_#{removed_user_id}",
      { type: "conversation.hidden", conversationId: @conversation.id }
    )
    head :no_content
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id])
    return if @conversation

    render_error("CONVERSATION_NOT_FOUND", "Conversation tidak ditemukan", :not_found)
  end

  def ensure_group
    return unless @conversation
    return if @conversation.kind == "group"

    render_error("GROUP_REQUIRED", "Anggota hanya dapat dikelola di group conversation", :unprocessable_entity)
  end

  def ensure_participant
    return unless @conversation
    return if @conversation.conversation_participants.exists?(user_id: current_user.id)

    render_error("FORBIDDEN", "Anda bukan anggota group conversation ini", :forbidden)
  end

  def broadcast_to_members(type)
    @conversation.participants.each do |member|
      ActionCable.server.broadcast(
        "user_#{member.id}",
        { type: type, conversationId: @conversation.id }
      )
    end
  end
end
