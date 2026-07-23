class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url, :message_body_param, :canned_responses_enabled, :canned_response_object, :text_area_rows, :text_area_required, :text_area_object_name, :text_area_id_suffix

  def initialize(form:, preview_message_url:, message_body_param:, canned_responses_enabled: false, canned_response_object: nil, text_area_rows: 4, text_area_required: true, text_area_object_name: :message, text_area_id_suffix: :message)
    super()

    @form = form
    @preview_message_url = preview_message_url
    @message_body_param = message_body_param
    @canned_responses_enabled = canned_responses_enabled
    @canned_response_object = canned_response_object
    @text_area_rows = text_area_rows
    @text_area_required = text_area_required
    @text_area_object_name = text_area_object_name
    @text_area_id_suffix = text_area_id_suffix
  end

  private

  def canned_responses
    user_canned_responses = User.session.canned_responses.where(decision_type: nil)
    return user_canned_responses unless [Project, Package, BsRequest, BsRequestAction].include?(@canned_response_object.class)

    user_canned_responses.or(@canned_response_object.canned_responses.where(decision_type: nil)).order(:title)
  end

  def placeholder
    case text_area_object_name
    when :decision
      "Write your comment or decision...(Markdown markup is only supported for comments, not for decisions)"
    when :body
      "Write your comment here... (Markdown markup is supported)"
    else
      "Write your #{text_area_object_name} here... (Markdown markup is supported)"
    end
  end
end
