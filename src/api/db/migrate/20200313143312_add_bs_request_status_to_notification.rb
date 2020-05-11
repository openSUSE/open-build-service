class AddBsRequestStatusToNotification < ActiveRecord::Migration[5.2]
  def change
    add_column :notifications, :bs_request_status, :string, collation: 'utf8_unicode_ci'
  end
end
