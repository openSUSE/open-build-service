class RemoveResponseUrlFromWorkflowRuns < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :workflow_runs, :response_url, :string }
  end
end
