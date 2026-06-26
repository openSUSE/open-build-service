class TimeComponentPreview < ViewComponent::Preview
  def with_time_in_the_past
    render(TimeComponent.new(time: 2.days.ago))
  end

  def with_time_in_the_present
    render(TimeComponent.new(time: Time.now.utc))
  end

  def with_time_in_the_future
    render(TimeComponent.new(time: 2.weeks.since))
  end
end
