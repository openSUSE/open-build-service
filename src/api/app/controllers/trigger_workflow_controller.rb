class TriggerWorkflowController < TriggerController
  skip_before_action :set_package
  before_action :set_scm_event
  before_action :validate_scm_event

  # TODO: split into different controllers, there is some behaviour that only applies to one specific kind of token.
  def create
    authorize @token
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
    raise InvalidToken unless @gitlab_event.present? || @github_event.present?
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
    JSON.parse(request.body.read)
  end
end
