class ChartComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/chart_component/request_build_results_chart
  def request_build_results_chart
    render(ChartComponent.new(actions: actions))
  end

  private

  def actions
    BsRequest.joins(:bs_request_actions).where(bs_request_actions: { type: :submit }).last.bs_request_actions
  end
end
