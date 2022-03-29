class CreateRequestJsonPayloadColumnInWorkflowRuns < ActiveRecord::Migration[6.1]
  def change
    add_column :workflow_runs, :request_json_payload, :json
  end
end
