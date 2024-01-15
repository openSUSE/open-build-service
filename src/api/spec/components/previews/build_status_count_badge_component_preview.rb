class BuildStatusCountBadgeComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/build_status_count_badge_component
  def succeeded
    render BuildStatusCountBadgeComponent.new(category: 'succeeded', count: 1)
  end

  def failed
    render BuildStatusCountBadgeComponent.new(category: 'failed', count: 3)
  end

  def processing
    render BuildStatusCountBadgeComponent.new(category: 'processing', count: 12)
  end

  def blocked
    render BuildStatusCountBadgeComponent.new(category: 'blocked', count: 35)
  end

  def disabled
    render BuildStatusCountBadgeComponent.new(category: 'disabled', count: 7)
  end
end
