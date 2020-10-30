class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
    RabbitmqBus.send_to_bus('metrics', "user in_beta=#{User.in_beta.count},in_rollout=#{User.in_rollout.count},count=#{User.count},#{role_fields},#{state_fields}")
  end

  private

  def role_fields
    Role.global.pluck(:title).map { |role_title| "#{role_title.downcase}=#{Role.find_by(title: role_title).users.count}" }.join(',')
  end

  def state_fields
    User::STATES.map { |state| "#{state}=#{User.where(state: state).count}" }.join(',')
  end
end
