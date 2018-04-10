# frozen_string_literal: true
class RemoveProjectAndPackageFromSubscription < ActiveRecord::Migration[4.2]
  def change
    remove_column :event_subscriptions, :package_id
    remove_column :event_subscriptions, :project_id
  end
end
