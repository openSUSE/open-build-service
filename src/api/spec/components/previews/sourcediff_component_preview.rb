class SourcediffComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/sourcediff_component/preview
  def preview
    bs_request = BsRequest.last
    opts = { filelimit: nil, tarlimit: nil, diff_to_superseded: nil, diffs: true, cacheonly: 1 }
    action = bs_request.send(:action_details, opts, xml: bs_request.bs_request_actions.last)
    render(SourcediffComponent.new(bs_request: bs_request, action: action, index: 0))
  end
end
