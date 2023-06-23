class AddPayloadDataToWorkflowRun < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :hook_action, :string
    add_column :workflow_runs, :repository_name, :string
    add_column :workflow_runs, :repository_owner, :string
    add_column :workflow_runs, :event_source_name, :string
    add_column :workflow_runs, :generic_event_type, :string
  end
end
