class SetDefaultValueForTypeInNotifications < ActiveRecord::Migration[6.0]
  def change
    change_column_default :notifications, :type, from: nil, to: ''
  end
end
