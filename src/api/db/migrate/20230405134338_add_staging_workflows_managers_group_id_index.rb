class AddStagingWorkflowsManagersGroupIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :staging_workflows, %w[managers_group_id], name: :index_staging_workflows_managers_group_id, unique: true
  end
end
