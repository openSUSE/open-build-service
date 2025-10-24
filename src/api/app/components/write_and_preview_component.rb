class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url, :message_body_param, :text_area_attributes, :canned_responses_enabled, :commentable_id,
              :commentable_type, :diff_file_index, :diff_line

  def initialize(form:, preview_message_url:, message_body_param:, text_area_attributes: {}, canned_responses_enabled: false,
                 commentable_id: nil, commentable_type: nil, diff_file_index: nil, diff_line: nil)
    super()

    @form = form
    @preview_message_url = preview_message_url
    @message_body_param = message_body_param
    @text_area_attributes = text_area_attributes_defaults.merge(text_area_attributes)
    @canned_responses_enabled = canned_responses_enabled
    @commentable_id = commentable_id
    @commentable_type = commentable_type
    @diff_file_index = diff_file_index
    @diff_line = diff_line
  end

  private

  def text_area_attributes_defaults
    { rows: 4, placeholder: 'Write your message here... (Markdown markup is supported)', required: true,
      object_name: :message, id_suffix: 'message' }
  end
end
