class DailyUserActivityMeasurementJob < ApplicationJob
  queue_as :quick

  def perform
    return unless CONFIG['amqp_options']

    RabbitmqBus.send_to_bus('metrics', "user #{user_fields}")
  end

  private

  def user_fields
    user_measures.map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def user_measures
    {
      seen: User.seen_since(1.day.ago).count
    }
  end
end
