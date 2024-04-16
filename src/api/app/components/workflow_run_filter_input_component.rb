class WorkflowRunFilterInputComponent < ApplicationComponent
  attr_accessor :text, :filter_item, :selected_input_value, :placeholder

  def initialize(text:, filter_item:, selected_input_filter:, placeholder:)
    super

    @text = text
    @filter_item = filter_item
    @placeholder = placeholder
    @selected_input_value = selected_input_filter.with_indifferent_access[filter_item] if selected_input_filter
  end
end
