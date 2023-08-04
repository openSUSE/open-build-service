class AddBsRequestToEventSubscription < ActiveRecord::Migration[7.0]
  def change
    add_reference :event_subscriptions, :bs_request, foreign_key: true, type: :integer
  end
end
