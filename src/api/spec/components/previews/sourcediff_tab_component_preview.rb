class SourcediffTabComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/sourcediff_tab_component/preview
  def preview
    bs_request = BsRequest.last
    opts = { filelimit: nil, tarlimit: nil, diff_to_superseded: nil, diffs: true, cacheonly: 1 }
    action = bs_request.send(:action_details, opts, xml: bs_request.bs_request_actions.last)
    render(SourcediffTabComponent.new(bs_request: bs_request, action: action, active: action[:name], index: 0))
  end
end
