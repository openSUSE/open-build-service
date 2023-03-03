class DiffListComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/diff_list_component/preview
  def preview
    bs_request = BsRequest.joins(:bs_request_actions).where(bs_request_actions: { type: :submit }).last
    opts = { filelimit: nil, tarlimit: nil, diff_to_superseded: nil, diffs: true, cacheonly: 1 }
    action = bs_request.send(:action_details, opts, xml: bs_request.bs_request_actions.where(type: :submit).last)
    render(DiffListComponent.new(diff_list: action[:sourcediff].last['files']))
  end
end
