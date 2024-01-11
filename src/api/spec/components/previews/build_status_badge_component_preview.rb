class BuildStatusBadgeComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/build_status_badge_component
  def succeeded
    render BuildStatusBadgeComponent.new(status: 'succeeded', text: 'succeeded')
  end

  def failed
    render BuildStatusBadgeComponent.new(status: 'failed', text: 'failed')
  end

  def broken
    render BuildStatusBadgeComponent.new(status: 'broken', text: 'broken')
  end

  def scheduled
    render BuildStatusBadgeComponent.new(status: 'scheduled', text: 'scheduled')
  end

  def building
    render BuildStatusBadgeComponent.new(status: 'building', text: 'building')
  end

  def disabled
    render BuildStatusBadgeComponent.new(status: 'disabled', text: 'disabled')
  end

  def excluded
    render BuildStatusBadgeComponent.new(status: 'excluded', text: 'excluded')
  end

  def locked
    render BuildStatusBadgeComponent.new(status: 'locked', text: 'locked')
  end

  def deleting
    render BuildStatusBadgeComponent.new(status: 'deleting', text: 'deleting')
  end

  def unknown
    render BuildStatusBadgeComponent.new(status: 'unknown', text: 'unknown')
  end
end
