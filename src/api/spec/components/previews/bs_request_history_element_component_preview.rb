class BsRequestHistoryElementComponentPreview < ViewComponent::Preview
  def with_history_element_request_superseded
    render(BsRequestHistoryElementComponent.new(element: HistoryElement::RequestSuperseded.last))
  end

  def with_history_element_request_accepted
    render(BsRequestHistoryElementComponent.new(element: HistoryElement::RequestAccepted.last))
  end
end
