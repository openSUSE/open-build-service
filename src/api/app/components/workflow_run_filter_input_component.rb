class WorkflowRunFilterInputComponent < ApplicationComponent
  attr_accessor :text, :filter_item, :selected_input_filter, :placeholder, :token_id

  def initialize(text:, filter_item:, selected_input_filter:, placeholder:, token_id:)
    super

    @text = text
    @filter_item = filter_item
    @placeholder = placeholder
    @selected_input_filter = selected_input_filter
    @token_id = token_id
  end

  def selected_filter_value
    @selected_input_filter
  end
end
