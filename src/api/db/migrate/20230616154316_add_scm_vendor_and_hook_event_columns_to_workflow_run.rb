class AddScmVendorAndHookEventColumnsToWorkflowRun < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :scm_vendor, :string
    add_column :workflow_runs, :hook_event, :string
  end
end
