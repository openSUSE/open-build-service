class CreateWorkflowRuns < ActiveRecord::Migration[6.1]
  def change
    create_table :workflow_runs, id: :integer do |t|
      t.text :request_headers, null: false
      t.text :request_payload, null: false
      t.integer :status, limit: 1, default: 0, null: false
      t.text :response_body
      t.string :response_url

      t.timestamps

      t.belongs_to :token, index: true, type: :integer, null: false
    end
  end
end
