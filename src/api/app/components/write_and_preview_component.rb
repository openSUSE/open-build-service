class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url, :message_body_param, :text_area_attributes, :canned_responses_enabled, :bs_request

  def initialize(form:, preview_message_url:, message_body_param:, text_area_attributes: {}, canned_responses_enabled: false, canned_response_object: nil)
    super()

    @form = form
    @preview_message_url = preview_message_url
    @message_body_param = message_body_param
    @text_area_attributes = text_area_attributes_defaults.merge(text_area_attributes)
    @canned_responses_enabled = canned_responses_enabled
    @canned_response_object = canned_response_object
  end

  private

  def request_canned_responses
    return CannedResponse.none if bs_request.nil?

    bs_request.canned_responses.where(decision_type: nil)
  end

  def text_area_attributes_defaults
    { rows: 4, placeholder: 'Write your message here... (Markdown markup is supported)', required: true,
      object_name: :message, id_suffix: 'message' }
  end
end
