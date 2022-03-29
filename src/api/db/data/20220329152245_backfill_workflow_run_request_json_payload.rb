# frozen_string_literal: true

class BackfillWorkflowRunRequestJsonPayload < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    WorkflowRun.unscoped.in_batches do |relation|
      relation.each { |workflow_run| workflow_run.update(request_json_payload: workflow_run.request_payload) }
      sleep(0.01)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
