class Conversation < ApplicationRecord
  has_many :conversation_participants,
           dependent: :destroy

  has_many :participants,
           through: :conversation_participants,
           source: :user

  has_many :messages,
           dependent: :destroy

  validates :kind,
            inclusion: {
              in: %w[direct group]
            }
    def create
    participant_ids = Array(params[:participantIds])
                            .map(&:to_s)
                            .uniq

    participant_ids << current_user.id.to_s

    users = User.where(id: participant_ids)

    if users.count != participant_ids.length
        return render_error(
        "USER_NOT_FOUND",
        "Salah satu user tidak ditemukan",
        :unprocessable_entity
        )
    end

    kind = params[:kind].presence || "direct"

    if kind == "direct" && participant_ids.length != 2
        return render_error(
        "INVALID_PARTICIPANTS",
        "Direct conversation harus memiliki 2 peserta",
        :unprocessable_entity
        )
    end

    conversation = Conversation.create!(
        kind: kind,
        title: params[:title],
        avatar_url: params[:avatarUrl]
    )

    participant_ids.each do |user_id|
        conversation.conversation_participants.create!(
        user_id: user_id
        )
    end

    render json: serialize_conversation(conversation),
            status: :created
    end
end