class BsRequestActionDescriptionComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/bs_request_action_description_component/submit_preview
  def submit_preview
    bs_request = BsRequest.joins(:bs_request_actions).where(bs_request_actions: { type: :submit }).last
    render(BsRequestActionDescriptionComponent.new(action: bs_request.bs_request_actions.last))
  end

  def add_role_preview
    bs_request = BsRequest.joins(:bs_request_actions).where(bs_request_actions: { type: :add_role }).last
    render(BsRequestActionDescriptionComponent.new(action: bs_request.bs_request_actions.where(type: 'add_role').first))
  end
end
