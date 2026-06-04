class CreateNotifiedPackages < ActiveRecord::Migration[7.2]
  def up
    create_table :notified_packages do |t|
      t.bigint :notification_id, null: false
      t.string :package_name, limit: 255, null: false
      t.datetime :created_at, null: false

      t.index :notification_id, name: 'index_notified_packages_on_notification_id'
      t.index :package_name, name: 'index_notified_packages_on_package_name'
      t.index [:notification_id, :package_name], unique: true,
              name: 'index_notified_packages_on_notification_id_and_package_name'
    end

    safety_assured do
      begin
        execute "SET SESSION foreign_key_checks = 0"
        add_foreign_key :notified_packages, :notifications
      ensure
        execute "SET SESSION foreign_key_checks = 1"
      end
    end
  end

  def down
    remove_foreign_key :notified_packages, :notifications
    drop_table :notified_packages
  end
end
