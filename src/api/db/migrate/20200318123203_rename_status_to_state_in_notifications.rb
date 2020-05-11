class RenameStatusToStateInNotifications < ActiveRecord::Migration[5.2]
  def change
    rename_column :notifications, :bs_request_status, :bs_request_state
  end
end
