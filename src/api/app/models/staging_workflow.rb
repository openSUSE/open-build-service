class StagingWorkflow < ApplicationRecord
  belongs_to :project, inverse_of: :staging
  has_many :staging_projects, class_name: 'Project', inverse_of: :staging_workflow, dependent: :nullify
end
