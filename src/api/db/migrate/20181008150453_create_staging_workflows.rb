class CreateStagingWorkflows < ActiveRecord::Migration[5.2]
  def change
    create_table :staging_workflows, id: :integer do |t|
      t.references :project, index: { unique: true }

      t.timestamps
    end

    change_table :projects do |t|
      t.references :staging_workflow, index: true
    end
  end
end
