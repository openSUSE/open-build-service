class MeasurementsJob < ApplicationJob
  queue_as :quick

  def perform
    RabbitmqBus.send_to_bus('metrics', "group count=#{Group.count}")
  end
end
