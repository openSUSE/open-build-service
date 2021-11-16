class AddResponseUrlToWorkflowRuns < ActiveRecord::Migration[6.1]
  def change
    add_column :workflow_runs, :response_url, :string
  end
end
