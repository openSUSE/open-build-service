class SponsorsComponentPreview < ViewComponent::Preview
  def with_default_config
    render(SponsorsComponent.new)
  end
end
