class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
    RabbitmqBus.send_to_bus('metrics', "user in_beta=#{User.in_beta.count},in_rollout=#{User.in_rollout.count},count=#{User.count},#{state_fields}")
  end

  private

  def state_fields
    User::STATES.map { |state| "#{state}=#{User.where(state: state).count}" }.join(',')
  end
end
