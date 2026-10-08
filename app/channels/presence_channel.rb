class PresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "presence"

    ActionCable.server.broadcast(
      "presence",
      {
        type: "presence.changed",
        userId: current_user.id,
        online: true
      }
    )
  end

  def unsubscribed
    ActionCable.server.broadcast(
      "presence",
      {
        type: "presence.changed",
        userId: current_user.id,
        online: false
      }
    )
  end
end