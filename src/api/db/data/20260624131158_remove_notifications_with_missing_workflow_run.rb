# frozen_string_literal: true

class RemoveNotificationsWithMissingWorkflowRun < ActiveRecord::Migration[7.2]
  def up
    workflow_run_notifications = Notification.where(notifiable_type: 'WorkflowRun')
    orphaned_workflow_run_notifications = workflow_run_notifications.where.not(notifiable_id: WorkflowRun.select(:id))
    orphaned_workflow_run_notifications.destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
