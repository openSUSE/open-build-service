class ProjectFlagGroup < ActiveRecord::Base
  belongs_to :db_project 
  belongs_to :flag_group_type 
  has_many :project_flags

end
