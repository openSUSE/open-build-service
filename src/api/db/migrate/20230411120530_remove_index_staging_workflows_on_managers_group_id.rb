class RemoveIndexStagingWorkflowsOnManagersGroupId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'staging_workflows', 'managers_group_id', name: 'index_staging_workflows_on_managers_group_id'
  end
end
