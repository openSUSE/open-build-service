class FuzzyTimeComponentPreview < ViewComponent::Preview
  def with_time_in_the_past
    render(FuzzyTimeComponent.new(time: 2.days.ago))
  end

  def with_time_in_the_present
    render(FuzzyTimeComponent.new(time: 2.seconds.ago))
  end
end
