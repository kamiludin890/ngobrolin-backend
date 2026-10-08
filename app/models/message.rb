class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender,
             class_name: "User"

  validates :text,
            presence: true,
            length: {
              maximum: 5000
            }

  validates :client_message_id,
            presence: true,
            length: {
              maximum: 200
            }

  validates :client_message_id,
            uniqueness: {
              scope: :conversation_id
            }
end