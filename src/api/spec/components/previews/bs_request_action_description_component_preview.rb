class BsRequestActionDescriptionComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/bs_request_action_description_component/submit_preview
  def submit_preview
    action = BsRequestAction.where(type: :submit).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def submit_preview_text_only
    action = BsRequestAction.where(type: :submit).last
    render(BsRequestActionDescriptionComponent.new(action: action, text_only: true))
  end

  def delete_preview
    action = BsRequestAction.where(type: :delete).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def delete_preview_text_only
    action = BsRequestAction.where(type: :delete).last
    render(BsRequestActionDescriptionComponent.new(action: action, text_only: true))
  end

  def add_role_preview
    action = BsRequestAction.where(type: :add_role).first
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def change_devel_preview
    action = BsRequestAction.where(type: :change_devel).first
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def change_devel_preview_text_only
    action = BsRequestAction.where(type: :change_devel).first
    render(BsRequestActionDescriptionComponent.new(action: action, text_only: true))
  end
end
