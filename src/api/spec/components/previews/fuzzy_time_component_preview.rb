class FuzzyTimeComponentPreview < ViewComponent::Preview
  def with_time_in_the_past
    render(FuzzyTimeComponent.new(time: 2.days.ago))
  end

  def with_time_in_the_present
    render(FuzzyTimeComponent.new(time: Time.now.utc))
  end

  def with_time_in_the_future
    render(FuzzyTimeComponent.new(time: 2.weeks.since))
  end
end
