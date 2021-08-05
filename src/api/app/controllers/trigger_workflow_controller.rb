class TriggerWorkflowController < TriggerController
  skip_before_action :set_project, :set_package, :set_object_to_authorize, :set_multibuild_flavor
  before_action :set_scm_event
  before_action :validate_scm_event

  def create
    authorize @token, :trigger?
    @token.user.run_as do
      @token.call(scm: scm, event: event, payload: payload)
      render_ok
    end
  end

  private

  def set_scm_event
    @gitlab_event = request.env['HTTP_X_GITLAB_EVENT']
    @github_event = request.env['HTTP_X_GITHUB_EVENT']
  end

  def validate_scm_event
    raise BadScmHeaders unless @gitlab_event.present? || @github_event.present?
  end

  def scm
    if @gitlab_event
      'gitlab'
    elsif @github_event
      'github'
    end
  end

  def event
    @github_event || @gitlab_event
  end

  def payload
    request_body = request.body.read
    raise BadScmPayload if request_body.blank?

    begin
      JSON.parse(request_body)
    rescue JSON::ParserError
      raise BadScmPayload
    end
  end
end
