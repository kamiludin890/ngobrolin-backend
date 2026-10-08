class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar

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

  validate :avatar_is_supported

  private

  def avatar_is_supported
    return unless avatar.attached?

    unless avatar.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:avatar, "harus berformat JPEG, PNG, atau WebP")
    end

    if avatar.byte_size > 5.megabytes
      errors.add(:avatar, "maksimal berukuran 5 MB")
    end
  end
end
