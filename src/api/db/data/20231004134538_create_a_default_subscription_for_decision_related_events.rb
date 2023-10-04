# frozen_string_literal: true

class CreateADefaultSubscriptionForDecisionRelatedEvents < ActiveRecord::Migration[7.0]
  def up
    # This automatically subscribes everyone to the cleared and favored decision events
    EventSubscription.create!(eventtype: Event::ClearedDecision.name, channel: :web, receiver_role: :reporter, enabled: true)
    EventSubscription.create!(eventtype: Event::FavoredDecision.name, channel: :web, receiver_role: :reporter, enabled: true)
    EventSubscription.create!(eventtype: Event::FavoredDecision.name, channel: :web, receiver_role: :offender, enabled: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
