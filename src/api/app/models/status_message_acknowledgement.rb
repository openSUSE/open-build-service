class StatusMessageAcknowledgement < ApplicationRecord
  belongs_to :status_message
  belongs_to :user

  validates :status_message, presence: true
  validates :user, presence: true

  validates :status_message_id, uniqueness: { scope: :user_id, message: 'You have already acknowledged the message' }
end
