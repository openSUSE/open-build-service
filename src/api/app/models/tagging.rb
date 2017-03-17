class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true

  belongs_to :user
  belongs_to :tag
  belongs_to :projects,  class_name: "Project",
                            foreign_key: "taggable_id"
  belongs_to :packages,  class_name: "Package",
                            foreign_key: "taggable_id"
end

