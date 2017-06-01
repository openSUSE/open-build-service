class DigestEmailEvent < ApplicationRecord
  belongs_to :digest_email
  belongs_to :event, class_name: 'Event::Base', foreign_key: :event_id
end

# == Schema Information
#
# Table name: digest_email_events
#
#  id              :integer          not null, primary key
#  digest_email_id :integer          not null
#  event_id        :integer          not null
#
