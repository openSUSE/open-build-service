class Rating < ActiveRecord::Base

  belongs_to :projects, :class_name => "Project", :foreign_key => "db_object_id"
  belongs_to :db_packages, :class_name => "DbPackage", :foreign_key => "db_object_id"


end
