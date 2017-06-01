class DigestEmail < ApplicationRecord
  belongs_to :event_subscription
end

# == Schema Information
#
# Table name: digest_emails
#
#  id                    :integer          not null, primary key
#  event_subscription_id :integer          not null, indexed
#  email_sent            :boolean          default(FALSE)
#  body_text             :text(65535)
#  body_html             :text(65535)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_digest_emails_on_event_subscription_id  (event_subscription_id)
#
