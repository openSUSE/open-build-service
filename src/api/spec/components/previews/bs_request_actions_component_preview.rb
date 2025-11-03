class BsRequestActionsComponentPreview < ViewComponent::Preview
  # Previews at http://HOST:PORT/rails/view_components/bs_request_actions_component
  def submit_preview
    bs_request = BsRequestAction.where(type: :submit).last.bs_request
    render(BsRequestActionsComponent.new(bs_request: bs_request))
  end

  def delete_preview
    bs_request = BsRequestAction.where(type: :delete).last.bs_request
    render(BsRequestActionsComponent.new(bs_request: bs_request))
  end

  def add_role_preview
    bs_request = BsRequestAction.where(type: :add_role).last.bs_request
    render(BsRequestActionsComponent.new(bs_request: bs_request))
  end

  def change_devel_preview
    bs_request = BsRequestAction.where(type: :change_devel).last.bs_request
    render(BsRequestActionsComponent.new(bs_request: bs_request))
  end
end
