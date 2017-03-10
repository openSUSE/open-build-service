class Rating < ApplicationRecord
  belongs_to :projects, class_name: "Project", foreign_key: "db_object_id"
  belongs_to :packages, class_name: "Package", foreign_key: "db_object_id"
end

# == Schema Information
#
# Table name: ratings
#
#  id             :integer          not null, primary key
#  score          :integer
#  db_object_id   :integer
#  db_object_type :string(255)
#  created_at     :datetime
#  user_id        :integer
#
# Indexes
#
#  object  (db_object_id)
#  user    (user_id)
#
