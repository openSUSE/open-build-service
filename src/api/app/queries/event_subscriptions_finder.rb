class EventSubscriptionsFinder
  def initialize(relation = EventSubscription.all)
    @relation = relation
  end

  def for_scm_channel_with_token(event_type:, event_package:)
    @relation
      .where(eventtype: event_type,
             package: event_package,
             channel: :scm)
      .where.not(token_id: nil)
  end
end
