class CreateExecutedWorkflowSteps < ActiveRecord::Migration[6.1]
  def change
    create_table :executed_workflow_steps, id: :integer do |t|
      t.string :name
      t.text :summary

      t.timestamps
      t.belongs_to :workflow_run, index: true, type: :integer, null: false
    end
  end
end
