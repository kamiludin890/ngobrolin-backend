class ChatChannel < ApplicationCable::Channel
  def subscribed
    conversation_id = params[:conversation_id]

    conversation = current_user.conversations.find_by(
      id: conversation_id
    )

    return reject unless conversation

    stream_from "conversation_#{conversation.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
