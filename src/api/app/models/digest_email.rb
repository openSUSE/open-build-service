class DigestEmail < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_and_belongs_to_many :events, through: :digest_email_events,
                                   class_name: 'Event::Base',
                                   foreign_key: :digest_email_id,
                                   association_foreign_key: :event_id
end

# == Schema Information
#
# Table name: digest_emails
#
#  id         :integer          not null, primary key
#  user_id    :integer          indexed
#  group_id   :integer          indexed
#  sent_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_digest_emails_on_group_id  (group_id)
#  index_digest_emails_on_user_id   (user_id)
#
