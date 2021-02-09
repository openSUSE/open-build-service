class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
    RabbitmqBus.send_to_bus('metrics', "user #{measurements_to_fields(users_measurements)}")
    RabbitmqBus.send_to_bus('metrics', "notification #{measurements_to_fields(notifications_measurements)}")
  end

  private

  def measurements_to_fields(measurements)
    measurements.map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def users_measurements
    {
      in_beta: User.in_beta.count,
      in_rollout: User.in_rollout.count,
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

  def notifications_measurements
    {
      count: Notification.count,
      for_web: Notification.for_web.count,
      for_rss: Notification.for_rss.count,
      read: NotificationsFinder.new.read.count,
      unread: NotificationsFinder.new.unread.count,
      about_comments: Notification.where(notifiable_type: 'Comment').count,
      about_requests: Notification.where(notifiable_type: 'BsRequest').count
    }
  end
end
