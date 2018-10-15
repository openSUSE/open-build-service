class CreateStagingWorkflowsManagers < ActiveRecord::Migration[5.2]
  def change
    create_table :staging_workflows_managers, id: :integer do |t|
      t.belongs_to :user, index: true, type: :integer
      t.belongs_to :staging_workflow, index: true, type: :integer

      t.timestamps
      t.index [:user_id, :staging_workflow_id], unique: true, name: 'manager_once_per_staging_workflow'
    end
  end
end
