class WorkflowRunFilterInputComponent < ApplicationComponent
  attr_accessor :text, :filter_name, :selected_input_value, :placeholder

  def initialize(text:, filter_name:, selected_input_filter:, placeholder:)
    super

    @text = text
    @filter_name = filter_name
    @placeholder = placeholder
    @selected_input_value = selected_input_filter.with_indifferent_access[filter_name] if selected_input_filter
  end
end
