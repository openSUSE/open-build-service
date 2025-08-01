class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url, :message_body_param, :text_area_attributes, :canned_responses_enabled

  def initialize(form:, preview_message_url:, message_body_param:, text_area_attributes: {}, canned_responses_enabled: false)
    super

    @form = form
    @preview_message_url = preview_message_url
    @message_body_param = message_body_param
    @text_area_attributes = text_area_attributes_defaults.merge(text_area_attributes)
    @canned_responses_enabled = canned_responses_enabled
  end

  private

  def text_area_attributes_defaults
    { rows: 4, placeholder: 'Write your message here... (Markdown markup is supported)', required: true,
      object_name: :message, id_suffix: 'message' }
  end
end
