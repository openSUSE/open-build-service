class AddBsRequestToEventSubscription < ActiveRecord::Migration[7.0]
  def change
    add_column :event_subscriptions, :bs_request_id, :integer
    add_index :event_subscriptions, :bs_request_id
  end
end
