# frozen_string_literal: true

class RemoveWorkflowRunsForDeleteEvents < ActiveRecord::Migration[7.2]
  def up
    WorkflowRun.where('status = ? AND request_payload LIKE ?', 2, '%"after":"0000000000000000000000000000000000000000"%').delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
