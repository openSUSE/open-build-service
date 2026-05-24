class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url, :message_body_param, :text_area_attributes, :canned_responses_enabled, :commentable_id,
              :commentable_type, :diff_file_index, :diff_line, :bs_request, :user

  def initialize(form:, preview_message_url:, message_body_param:, text_area_attributes: {}, canned_responses_enabled: false,
                 commentable_id: nil, commentable_type: nil, diff_file_index: nil, diff_line: nil, bs_request: nil, user: nil)
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
    @bs_request = bs_request
    @user = user
  end

  def canned_responses
    return CannedResponse.none unless user

    user_canned_responses = user.canned_responses.where(decision_type: nil)

    user_canned_responses.or(request_canned_responses).order(:title)
  end

  private

  def request_canned_responses
    request = if bs_request.respond_to?(:canned_responses)
                bs_request
              elsif bs_request.respond_to?(:bs_request)
                bs_request.bs_request
              end

    return CannedResponse.none unless request

    request.canned_responses.where(decision_type: nil)
  end

  def text_area_attributes_defaults
    { rows: 4, placeholder: 'Write your message here... (Markdown markup is supported)', required: true,
      object_name: :message, id_suffix: 'message' }
  end
end
