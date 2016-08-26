class MaintainedProject < ApplicationRecord
  belongs_to :project, foreign_key: :project_id
  belongs_to :maintenance_project, :class_name => "Project", foreign_key: :maintenance_project_id
end
