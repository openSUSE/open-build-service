# One instance of this model represents a bunch of artifacts (related to one step).
# We chose WorkflowArtifactsPerStep name over names like WorkflowArtifact or WorkflowArtifacts
# because it fits better semantically and follows Rails convention of being singular.
class WorkflowArtifactsPerStep < ApplicationRecord
  belongs_to :workflow_run, optional: false

  serialize :artifacts, coder: JSON

  validates :step, :artifacts, presence: true
end

# == Schema Information
#
# Table name: workflow_artifacts_per_steps
#
#  id              :integer          not null, primary key
#  artifacts       :text(65535)
#  step            :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  workflow_run_id :integer          not null, indexed
#
# Indexes
#
#  index_workflow_artifacts_per_steps_on_workflow_run_id  (workflow_run_id)
#
