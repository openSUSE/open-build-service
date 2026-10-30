# frozen_string_literal: true

class RemoveReportNotificationsWithoutReportNotifiable < ActiveRecord::Migration[8.1]
  def up
    report_notifications_without_notifiable = NotificationReport.where.not(notifiable_id: Report.select(:id))
    report_notifications_without_notifiable.in_batches.destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
