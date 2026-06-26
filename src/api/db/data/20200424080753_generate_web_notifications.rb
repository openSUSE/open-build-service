class GenerateWebNotifications < ActiveRecord::Migration[6.0]
  def up
    Notification.update(rss: true, web: true)
    update_existent_event_subscriptions
    generate_subscripitions
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def update_existent_event_subscriptions
    enabled_subscriptions = EventSubscription.where(channel: :instant_email)
    enabled_subscriptions.update(enabled: true)

    disabled_subscriptions = EventSubscription.where(channel: :disabled)
    disabled_subscriptions.update(channel: :instant_email)
  end

  def generate_subscripitions
    subscriptions = EventSubscription.where(channel: :instant_email, enabled: true)
    subscriptions.each do |subscription|
      create_subscription_for_channel(subscription, :web)
      create_subscription_for_channel_rss(subscription, subscription.subscriber)
    end
  end

  def create_subscription_for_channel(subscription, channel)
    return if eventtype_disabled_for_web_and_rss?(subscription.eventtype)

    subscription = EventSubscription.find_or_initialize_by(user_id: subscription.user_id,
                                                           group_id: subscription.group_id,
                                                           receiver_role: subscription.receiver_role,
                                                           eventtype: subscription.eventtype,
                                                           channel: channel)
    subscription.enabled = true
    subscription.save!
  end

  def create_subscription_for_channel_rss(subscription, subscriber)
    return if subscriber && !subscriber.try(:rss_token)

    create_subscription_for_channel(subscription, :rss)
  end

  def eventtype_disabled_for_web_and_rss?(event_type)
    ['Event::BuildFail', 'Event::ServiceFail'].include?(event_type)
  end
end
