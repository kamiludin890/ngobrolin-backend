class Conversation < ApplicationRecord
  has_many :conversation_participants,
           dependent: :destroy

  has_many :participants,
           through: :conversation_participants,
           source: :user

  has_many :messages,
           dependent: :destroy

  has_one_attached :avatar

  validates :kind,
            inclusion: {
              in: %w[direct group]
            }
  validates :description,
            length: { maximum: 2500 }

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
