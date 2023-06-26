class AddIdsToWorkflowRun < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :event_uuid, :string
    add_column :workflow_runs, :webhook_id, :string
  end
end
