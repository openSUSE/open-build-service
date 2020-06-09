class Rating < ApplicationRecord
  belongs_to :projects, class_name: 'Project', foreign_key: 'db_object_id'
  belongs_to :packages, class_name: 'Package', foreign_key: 'db_object_id'
end

# == Schema Information
#
# Table name: ratings
#
#  id             :integer          not null, primary key
#  db_object_type :string(255)
#  score          :integer
#  created_at     :datetime
#  db_object_id   :integer          indexed
#  user_id        :integer          indexed
#
# Indexes
#
#  object  (db_object_id)
#  user    (user_id)
#
# Foreign Keys
#
#  ratings_ibfk_1  (user_id => users.id)
#
