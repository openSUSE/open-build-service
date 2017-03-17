class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  belongs_to :user
  belongs_to :tag
  belongs_to :projects,  class_name: "Project",
                            foreign_key: "taggable_id"
  belongs_to :packages,  class_name: "Package",
                            foreign_key: "taggable_id"
end

# == Schema Information
#
# Table name: taggings
#
#  id            :integer          not null, primary key
#  taggable_id   :integer          indexed => [taggable_type, tag_id, user_id]
#  taggable_type :string(255)      indexed, indexed => [taggable_id, tag_id, user_id]
#  tag_id        :integer          indexed, indexed => [taggable_id, taggable_type, user_id]
#  user_id       :integer          indexed => [taggable_id, taggable_type, tag_id], indexed
#
# Indexes
#
#  index_taggings_on_taggable_type  (taggable_type)
#  tag_id                           (tag_id)
#  taggings_taggable_id_index       (taggable_id,taggable_type,tag_id,user_id) UNIQUE
#  user_id                          (user_id)
#
# Foreign Keys
#
#  taggings_ibfk_1  (tag_id => tags.id)
#  taggings_ibfk_2  (user_id => users.id)
#
