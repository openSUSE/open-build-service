class BsRequestActionsSummaryComponentPreview < ViewComponent::Preview
  # Previews at http://HOST:PORT/rails/view_components/bs_request_actions_summary_component
  def single_action_preview
    bs_request = BsRequest.joins(:bs_request_actions).group(:id).having('COUNT(bs_request_actions.id) = 1').last
    render(BsRequestActionsSummaryComponent.new(bs_request: bs_request))
  end

  def multi_action_preview
    bs_request = BsRequest.joins(:bs_request_actions).group(:id).having('COUNT(bs_request_actions.id) > 1').last
    render(BsRequestActionsSummaryComponent.new(bs_request: bs_request))
  end
end
