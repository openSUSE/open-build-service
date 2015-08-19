class RemoveProjectAndPackageFromSubscription < ActiveRecord::Migration
  def change
    remove_column :event_subscriptions, :package_id 
    remove_column :event_subscriptions, :project_id
  end
end
