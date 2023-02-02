class WorkflowRunFilterLinkComponent < ApplicationComponent
  def initialize(text:, filter_item:, selected_filter:, token:, amount:)
    super

    @text = text
    @filter_item = filter_item
    @selected_filter = selected_filter
    @amount = amount || 0
    @token = token
  end

  def css_for_link
    workflow_run_filter_matches? ? 'active' : ''
  end

  def css_for_badge_color
    workflow_run_filter_matches? ? 'text-bg-light' : 'text-bg-primary'
  end

  private

  def workflow_run_filter_matches?
    if @selected_filter[:status].present?
      @filter_item[:status] == @selected_filter[:status]
    elsif @selected_filter[:generic_event_type].present?
      @filter_item[:generic_event_type] == @selected_filter[:generic_event_type]
    elsif @selected_filter.empty?
      @filter_item.empty?
    end
  end
end
