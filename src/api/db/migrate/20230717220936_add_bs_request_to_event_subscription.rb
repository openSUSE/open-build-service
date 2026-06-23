class AddBsRequestToEventSubscription < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_reference :event_subscriptions, :bs_request, foreign_key: true, type: :integer
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
