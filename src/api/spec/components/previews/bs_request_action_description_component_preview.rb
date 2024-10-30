class BsRequestActionDescriptionComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/bs_request_action_description_component/submit_preview
  def submit_preview
    action = BsRequestAction.where(type: :submit).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def add_role_preview
    action = BsRequestAction.where(type: :add_role).first
    render(BsRequestActionDescriptionComponent.new(action: action))
  end
end
