class AddPackageToEventsAndEventSubscriptions < ActiveRecord::Migration[6.0]
  def change
    safety_assured do # since strong_migrations cannot look inside the block of change_table
      change_table :events, bulk: true do |t|
        t.integer :package_id
        t.index :package_id
      end

      change_table :event_subscriptions, bulk: true do |t|
        t.integer :package_id
        t.index :package_id
      end
    end
  end
end
