# frozen_string_literal: true

class CreateEmailSubscriptionsForDecisionRelatedEvents < ActiveRecord::Migration[7.0]
  def up
    # This automatically subscribes everyone to the cleared and favored decision events
    EventSubscription.create(eventtype: Event::ClearedDecision.name, channel: :instant_email, receiver_role: :reporter, enabled: true)
    EventSubscription.create(eventtype: Event::FavoredDecision.name, channel: :instant_email, receiver_role: :reporter, enabled: true)
    EventSubscription.create(eventtype: Event::FavoredDecision.name, channel: :instant_email, receiver_role: :offender, enabled: true)
  end

  def down
    EventSubscription.where(eventtype: Event::ClearedDecision.name, channel: :instant_email, receiver_role: :reporter, enabled: true).destroy_all
    EventSubscription.where(eventtype: Event::FavoredDecision.name, channel: :instant_email, receiver_role: :reporter, enabled: true).destroy_all
    EventSubscription.where(eventtype: Event::FavoredDecision.name, channel: :instant_email, receiver_role: :offender, enabled: true).destroy_all
  end
end
