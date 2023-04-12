class AddScmStatusReportsWorkflowRunIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :scm_status_reports, %w[workflow_run_id], name: :index_scm_status_reports_workflow_run_id
  end
end
