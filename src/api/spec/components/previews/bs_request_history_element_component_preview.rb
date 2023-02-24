class BsRequestHistoryElementComponentPreview < ViewComponent::Preview
  # /rails/view_components/bs_request_history_element_component/with_history_element_request_superseded
  def with_history_element_request_superseded
    render(BsRequestHistoryElementComponent.new(element: HistoryElement::RequestSuperseded.last))
  end

  # /rails/view_components/bs_request_history_element_component/with_history_element_request_accepted
  def with_history_element_request_accepted
    render(BsRequestHistoryElementComponent.new(element: HistoryElement::RequestAccepted.last))
  end

  # /rails/view_components/bs_request_history_element_component/with_history_element_request_review_added
  def with_history_element_request_review_added
    render(BsRequestHistoryElementComponent.new(element: HistoryElement::RequestReviewAdded.last))
  end
end
