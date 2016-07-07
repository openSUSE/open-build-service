class Message < ApplicationRecord
  belongs_to :projects, :class_name => "Project", :foreign_key => "db_object_id"
  belongs_to :packages, :class_name => "Package", :foreign_key => "db_object_id"
  belongs_to :user
end
