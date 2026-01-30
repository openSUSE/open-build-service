class CreateDefaultTokenDisabledSubscriptions < ActiveRecord::Migration[7.0]
  def up
    EventSubscription.create(
      eventtype: 'Event::TokenDisabled',
      receiver_role: 'token_executor',
      channel: :web
    )
    EventSubscription.create(
      eventtype: 'Event::TokenDisabled',
      receiver_role: 'token_member',
      channel: :web
    )
  end

  def down
    EventSubscription.where(eventtype: 'Event::TokenDisabled').delete_all
  end
end
