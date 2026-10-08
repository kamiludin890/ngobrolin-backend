class User < ApplicationRecord
  has_secure_password

  has_many :conversation_participants,
           dependent: :destroy

  has_many :conversations,
           through: :conversation_participants

  has_many :sent_messages,
           class_name: "Message",
           foreign_key: :sender_id,
           dependent: :nullify

  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :email,
            presence: true,
            uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }

  normalizes :email, with: ->(email) { email.strip.downcase }
end