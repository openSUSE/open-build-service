class DigestEmail < ApplicationRecord
  belongs_to :event_subscription
  has_many :digest_email_events
  has_many :events, through: :digest_email_events, class_name: 'Event::Base'
end

# == Schema Information
#
# Table name: digest_emails
#
#  id                    :integer          not null, primary key
#  event_subscription_id :integer          indexed
#  sent_at               :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_digest_emails_on_event_subscription_id  (event_subscription_id)
#
