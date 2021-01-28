class AddGroupsUserIdToEventSubscriptions < ActiveRecord::Migration[6.0]
  def change
    # Strong Migrations does not support inspecting what happens inside a
    # change_table block, so we wrap it in a safety_assured { ... } block.
    safety_assured do
      change_table :event_subscriptions, bulk: true do |t|
        t.integer :groups_user_id
        t.index :groups_user_id
      end
    end
  end
end
