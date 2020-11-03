class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
    RabbitmqBus.send_to_bus('metrics', "user #{user_fields}")
  end

  private

  def user_fields
    user_measures.map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def user_measures
    {
      in_beta: User.in_beta.count,
      in_rollout: User.in_rollout.count,
      count: User.count
    }
      .merge(role_fields)
      .merge(state_fields)
  end

  def role_fields
    Role.global.pluck(:title).each_with_object({}) do |role_title, fields|
      fields[role_title.downcase.to_sym] = Role.find_by(title: role_title).users.count
      fields
    end
  end

  def state_fields
    User::STATES.each_with_object({}) do |state, fields|
      fields[state.to_sym] = User.where(state: state).count
      fields
    end
  end
end
