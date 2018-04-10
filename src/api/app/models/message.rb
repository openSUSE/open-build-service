# frozen_string_literal: true
class Message < ApplicationRecord
  belongs_to :projects, class_name: 'Project', foreign_key: 'db_object_id'
  belongs_to :packages, class_name: 'Package', foreign_key: 'db_object_id'
  belongs_to :user
end

# == Schema Information
#
# Table name: messages
#
#  id             :integer          not null, primary key
#  db_object_id   :integer          indexed
#  db_object_type :string(255)
#  user_id        :integer          indexed
#  created_at     :datetime
#  send_mail      :boolean
#  sent_at        :datetime
#  private        :boolean
#  severity       :integer
#  text           :text(65535)
#
# Indexes
#
#  object  (db_object_id)
#  user    (user_id)
#
