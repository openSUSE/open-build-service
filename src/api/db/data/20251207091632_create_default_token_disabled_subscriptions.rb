# frozen_string_literal: true

class CreateDefaultTokenDisabledSubscriptions < ActiveRecord::Migration[7.2]
  def up
    # Create default subscriptions for Event::TokenDisabled
    # This event is triggered when a workflow token is disabled due to authorization failures
    create_default_subscription('token_executor', :instant_email)
    create_default_subscription('token_executor', :web)
    create_default_subscription('token_member', :instant_email)
    create_default_subscription('token_member', :web)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def create_default_subscription(receiver_role, channel)
    EventSubscription.find_or_create_by!(
      eventtype: 'Event::TokenDisabled',
      receiver_role: receiver_role,
      channel: channel,
      user_id: nil,
      group_id: nil
    ) do |subscription|
      subscription.enabled = true
    end
  end
end
