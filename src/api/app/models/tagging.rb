class Tagging < ActiveRecord::Base
  belongs_to :taggable, :polymorphic => true

  belongs_to :user
  belongs_to :tag
  belongs_to :projects,  :class_name => "Project",
                            :foreign_key => "taggable_id"
  belongs_to :db_packages,  :class_name => "DbPackage",
                            :foreign_key => "taggable_id"
end
