class BsRequestActionDescriptionComponentPreview < ViewComponent::Preview
  # Previews at http://HOST:PORT/rails/view_components/bs_request_action_description_component/
  def add_role
    action = BsRequestAction.where(type: :add_role).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def change_devel
    action = BsRequestAction.where(type: :change_devel).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def delete
    action = BsRequestAction.where(type: :delete).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def maintenance_incident
    action = BsRequestAction.where(type: :maintenance_incident).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def maintenance_release
    action = BsRequestAction.where(type: :maintenance_release).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def release
    action = BsRequestAction.where(type: :release).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def set_bugowner
    action = BsRequestAction.where(type: :set_bugowner).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end

  def submit
    action = BsRequestAction.where(type: :submit).last
    render(BsRequestActionDescriptionComponent.new(action: action))
  end
end
