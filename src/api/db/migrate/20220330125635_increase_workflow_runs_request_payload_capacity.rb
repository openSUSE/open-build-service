class IncreaseWorkflowRunsRequestPayloadCapacity < ActiveRecord::Migration[6.1]
  def up
    safety_assured { change_column :workflow_runs, :request_payload, :longtext }
  end
end
