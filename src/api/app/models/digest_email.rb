class DigestEmail < ApplicationRecord
  belongs_to :event_subscription
  has_and_belongs_to_many :events, through: :digest_email_events,
                                   class_name: 'Event::Base',
                                   foreign_key: :digest_email_id,
                                   association_foreign_key: :event_id
end

# == Schema Information
#
# Table name: digest_emails
#
#  id                    :integer          not null, primary key
#  event_subscription_id :integer          not null
#  sent_at               :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
