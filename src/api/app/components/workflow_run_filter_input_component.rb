class WorkflowRunFilterInputComponent < ApplicationComponent
  attr_accessor :text, :selected_input_filter, :placeholder, :token_id

  def initialize(text:, selected_input_filter:, placeholder:, token_id:)
    super

    @text = text
    @placeholder = placeholder
    @selected_input_filter = selected_input_filter
    @token_id = token_id
  end

  def css_for_filter_item
    'active' if @selected_input_filter.present?
  end

  def selected_filter_value
    @selected_input_filter
  end
end
