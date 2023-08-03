class WorkflowRunFilterLinkComponent < ApplicationComponent
  def initialize(text:, filter_item:, selected_filter:, token:, amount:, icon: '')
    super

    @text = text
    @filter_item = filter_item
    @selected_filter = selected_filter
    @amount = amount || 0
    @token = token
    @icon = icon
  end

  def css_for_link
    workflow_run_filter_matches? ? 'active' : ''
  end

  def icon_tag
    tag.i(class: ['me-1', @icon, ('text-light' if workflow_run_filter_matches?)]) if @icon != ''
  end

  private

  def workflow_run_filter_matches?
    # None of the filter links is active when filtering by PR/MR number or commit SHA
    return false if @selected_filter[:pr_mr] || @selected_filter[:commit]

    if @selected_filter[:status].present?
      @filter_item[:status] == @selected_filter[:status]
    elsif @selected_filter[:generic_event_type].present?
      @filter_item[:generic_event_type] == @selected_filter[:generic_event_type]
    elsif @selected_filter.empty?
      @filter_item.empty?
    end
  end
end
