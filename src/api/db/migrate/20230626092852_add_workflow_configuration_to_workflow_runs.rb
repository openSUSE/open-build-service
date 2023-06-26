class AddWorkflowConfigurationToWorkflowRuns < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :workflow_configuration, :text
  end
end
