class EventSubscriptionsFinder
  def initialize(relation = EventSubscription.all)
    @relation = relation
  end

  def for_scm_channel_with_token(event_type:, event_package:, event_request:)
    @relation
      .where(eventtype: event_type,
             package: event_package,
             bs_request: event_request,
             channel: :scm)
      .where.not(token_id: nil)
  end
end
