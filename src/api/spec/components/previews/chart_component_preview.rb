class ChartComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/chart_component/request_build_results_chart
  def request_build_results_chart
    render(ChartComponent.new(raw_data: raw_data))
  end

  private

  def actions
    BsRequest.joins(:bs_request_actions).where(bs_request_actions: { type: :submit }).last.bs_request_actions
  end

  def raw_data
    ActionBuildResultsService::ChartDataExtractor.new(actions: actions).call
  end
end
