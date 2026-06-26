class AddConfigurationUrlAndPathColumnsToWorkflowRun < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_runs, :workflow_configuration_path, :string
    add_column :workflow_runs, :workflow_configuration_url, :string
  end
end
