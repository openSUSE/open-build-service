class StatusMessageAcknowledgement < ApplicationRecord
  belongs_to :status_message
  belongs_to :user

  validates :status_message_id, uniqueness: { scope: :user_id, message: 'You have already acknowledged the message' }
end

# == Schema Information
#
# Table name: status_message_acknowledgements
#
#  id                :integer          not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  status_message_id :integer          indexed
#  user_id           :integer          indexed
#
# Indexes
#
#  index_status_message_acknowledgements_on_status_message_id  (status_message_id)
#  index_status_message_acknowledgements_on_user_id            (user_id)
#
