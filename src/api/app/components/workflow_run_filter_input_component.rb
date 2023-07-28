class WorkflowRunFilterInputComponent < ApplicationComponent
  attr_accessor :text, :selected_input_filter, :placeholder, :token_id

  def initialize(text:, selected_input_filter:, placeholder:, token_id:)
    super

    @text = text
    @placeholder = placeholder
    @selected_input_filter = selected_input_filter
    @token_id = token_id
  end

  def css_for_label
    @selected_input_filter ? 'fs-6 fw-bold' : 'fs-6'
  end

  def css_for_input
    @selected_input_filter ? 'form-control form-control-sm mx-2 fw-bold' : 'form-control form-control-sm mx-2'
  end

  def css_for_button
    @selected_input_filter ? 'btn btn-sm btn-outline-success px-3 bg-primary text-light' : 'btn btn-sm btn-outline-success px-3'
  end

  def selected_filter_value
    @selected_input_filter
  end
end
