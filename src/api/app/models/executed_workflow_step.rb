# TODO: Please overwrite this comment with something explaining the model target
class ExecutedWorkflowStep < ApplicationRecord
  belongs_to :workflow_run
end

# == Schema Information
#
# Table name: executed_workflow_steps
#
#  id              :integer          not null, primary key
#  name            :string(255)
#  summary         :text(65535)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  workflow_run_id :integer          not null, indexed
#
# Indexes
#
#  index_executed_workflow_steps_on_workflow_run_id  (workflow_run_id)
#
