class RemoveConfigOption < ActiveRecord::Migration
  def change
    remove_column :configurations, :multiaction_notify_support
  end
end
