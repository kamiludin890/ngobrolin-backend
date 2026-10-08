class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender,
             class_name: "User"
  has_many_attached :attachments

  validates :text, length: { maximum: 5000 }, allow_blank: true

  validates :client_message_id,
            presence: true,
            length: {
              maximum: 200
            }

  validates :client_message_id,
            uniqueness: {
              scope: :conversation_id
            }

  validate :text_or_attachment_present
  validate :attachments_are_supported

  private

  def text_or_attachment_present
    errors.add(:base, "Pesan atau lampiran wajib diisi") if text.blank? && attachments.blank?
  end

  def attachments_are_supported
    errors.add(:attachments, "maksimal 5 file per pesan") if attachments.size > 5

    attachments.each do |attachment|
      unless attachment.content_type.in?(%w[
        image/jpeg image/png image/webp image/gif
        video/mp4 video/webm application/pdf text/plain
      ])
        errors.add(:attachments, "hanya mendukung gambar, video, PDF, atau teks")
      end

      errors.add(:attachments, "maksimal 20 MB per file") if attachment.byte_size > 20.megabytes
    end
  end
end
