class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
    RabbitmqBus.send_to_bus('metrics', "user #{measurements_to_fields(users_measurements)}")
    notifications_measurements
    subscription_measurements
    beta_features_measurements

    RabbitmqBus.send_to_bus('metrics', "token_workflow #{measurements_to_fields(token_workflow_measurements)}")
  end

  private

  def measurements_to_fields(measurements)
    measurements.map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def users_measurements
    {
      in_beta: User.in_beta.count,
      in_rollout: User.in_rollout.count,
      censored: User.where(censored: true).count,
      count: User.count
    }
      .merge(roles_measurements)
      .merge(states_measurements)
  end

  def roles_measurements
    Role.global.pluck(:title).each_with_object({}) do |role_title, fields|
      fields[role_title.downcase.to_sym] = Role.find_by(title: role_title).users.count
      fields
    end
  end

  def states_measurements
    User::STATES.each_with_object({}) do |state, fields|
      fields[state.to_sym] = User.where(state: state).count
      fields
    end
  end

  def subscription_measurements
    RabbitmqBus.send_to_bus('metrics', "event_subscription_count,default=true value=#{EventSubscription.where(user_id: nil).count}")

    EventSubscription.group(:channel).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "event_subscription_count,channel=#{type.first} value=#{type.second}")
    end

    EventSubscription.group(:enabled).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "event_subscription_count,enabled=#{type.first} value=#{type.second}")
    end

    EventSubscription.group(:eventtype).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "event_subscription_count,eventtype=#{type.first} value=#{type.second}")
    end

    EventSubscription.group(:receiver_role).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "event_subscription_count,receiver_role=#{type.first} value=#{type.second}")
    end
  end

  def notifications_measurements
    RabbitmqBus.send_to_bus('metrics', "notification_count,channel=web value=#{Notification.for_web.count}")
    RabbitmqBus.send_to_bus('metrics', "notification_count,channel=rss value=#{Notification.for_rss.count}")

    Notification.group(:subscriber_type).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "notification_count,subscriber=#{type.first} value=#{type.second}")
    end

    Notification.group(:delivered).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "notification_count,delivered=#{type.first} value=#{type.second}")
    end

    Notification.group(:notifiable_type).count.each do |type|
      RabbitmqBus.send_to_bus('metrics', "notification_count,notifiable=#{type.first} value=#{type.second}")
    end
  end

  def beta_features_measurements
    ENABLED_FEATURE_TOGGLES.pluck(:name).each do |feature_name|
      RabbitmqBus.send_to_bus('metrics', "beta_feature_count,feature=#{feature_name},status=disabled value=#{DisabledBetaFeature.where(name: feature_name).count}")
    end
  end

  def token_workflow_measurements
    tokens_with_custom_configuration_path = Token::Workflow.where.not(workflow_configuration_path: [nil, '']).count
    tokens_with_custom_configuration_url = Token::Workflow.where.not(workflow_configuration_url: [nil, '']).count

    {
      total_count: Token::Workflow.count,
      enabled: Token::Workflow.where(enabled: true).count,
      disabled: Token::Workflow.where(enabled: false).count,
      custom_configuration_path: tokens_with_custom_configuration_path,
      custom_configuration_url: tokens_with_custom_configuration_url,
      user_with_tokens: User.joins(:shared_workflow_tokens).distinct.count,
      groups_sharing_tokens: Group.joins(:shared_workflow_tokens).distinct.count
    }
  end
end
