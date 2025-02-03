class BsRequestDescriptionComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/bs_request_description_component/submit_preview
  def submit_preview
    bs_request = BsRequestAction.where(type: :submit).last.bs_request
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def submit_preview_text_only
    bs_request = BsRequestAction.where(type: :submit).last
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def delete_preview
    bs_request = BsRequestAction.where(type: :delete).last
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def delete_preview_text_only
    bs_request = BsRequestAction.where(type: :delete).last
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def add_role_preview
    bs_request = BsRequestAction.where(type: :add_role).first
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def change_devel_preview
    bs_request = BsRequestAction.where(type: :change_devel).first
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end

  def change_devel_preview_text_only
    bs_request = BsRequestAction.where(type: :change_devel).first
    render(BsRequestDescriptionComponent.new(bs_request: bs_request))
  end
end
