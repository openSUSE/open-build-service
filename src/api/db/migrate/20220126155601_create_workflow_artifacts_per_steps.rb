class CreateWorkflowArtifactsPerSteps < ActiveRecord::Migration[6.1]
  def change
    create_table :workflow_artifacts_per_steps, id: :integer do |t|
      t.belongs_to :workflow_run, index: true, null: false, type: :integer
      t.string :step
      t.text :artifacts

      t.timestamps
    end
  end
end
