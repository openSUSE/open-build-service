class WorkflowRunFilterCheckboxComponent < ApplicationComponent
  def initialize(text:, filter_item:, selected_filter:, token:, amount:, icon: '')
    super

    @text = text
    @filter_item = filter_item
    @selected_filter = selected_filter
    @amount = amount || 0
    @token = token
    @icon = icon
  end

  def icon_tag
    tag.i(class: ['me-1', @icon]) if @icon != ''
  end

  private

  def workflow_run_filter_matches?
    @selected_filter[@filter_item].present?
  end
end
