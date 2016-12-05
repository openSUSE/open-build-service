class GroupSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :event_subscriptions, :group_id, :integer
    add_index :event_subscriptions, :group_id
  end

  def self.down
    remove_index :event_subscriptions, :group_id
    remove_column :event_subscriptions, :group_id
  end
end
