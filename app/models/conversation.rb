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
end
