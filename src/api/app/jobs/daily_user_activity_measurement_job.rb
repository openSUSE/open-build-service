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
      seen: User.seen_since(1.day.ago).count,
      seen_week: User.seen_since(1.week.ago).count,
      seen_month: User.seen_since(1.month.ago).count,
      seen_quarter: User.seen_since(3.months.ago).count,
      seen_year: User.seen_since(1.year.ago).count
    }
  end
end
