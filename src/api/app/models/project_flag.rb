class ProjectFlag < ActiveRecord::Base
  belongs_to :project_flag_group
  belongs_to :flag_types

end
