class CreateScmStatusReportsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :scm_status_reports, id: :integer do |t|
      t.integer :workflow_run_id
      t.text :response_body, size: :long
      t.text :request_parameters, size: :long

      t.timestamps
    end
  end
end
