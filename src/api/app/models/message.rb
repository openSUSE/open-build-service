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
#  db_object_type :string(255)
#  private        :boolean
#  send_mail      :boolean
#  sent_at        :datetime
#  severity       :integer
#  text           :text(65535)
#  created_at     :datetime
#  db_object_id   :integer          indexed
#  user_id        :integer          indexed
#
# Indexes
#
#  object  (db_object_id)
#  user    (user_id)
#
