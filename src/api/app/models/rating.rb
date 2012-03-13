class Rating < ActiveRecord::Base

  belongs_to :db_projects, :class_name => "DbProject", :foreign_key => "db_object_id"
  belongs_to :db_packages, :class_name => "DbPackage", :foreign_key => "db_object_id"


end
