class TriggerWorkflowController < TriggerController
  # We don't need to validate that the body of the request is XML. We receive JSON
  skip_before_action :validate_xml_request, :set_project_name, :set_package_name, :set_project, :set_package, :set_object_to_authorize, :set_multibuild_flavor

  before_action :set_scm_event
  before_action :abort_trigger_if_ignored_pull_request_action
  before_action :create_workflow_run
  before_action :validate_scm_event

  def create
    authorize @token, :trigger?
    @token.user.run_as do
      validation_errors = @token.call(workflow_run: @workflow_run, scm_webhook: @scm_webhook)

      unless @workflow_run.status == 'fail' # The SCMStatusReporter might already set the status to 'fail', lets not overwrite it
        if validation_errors.none?
          @workflow_run.update(status: 'success', response_body: render_ok)
        else
          @workflow_run.update_as_failed(render_error(status: 400, message: validation_errors.to_sentence))
        end
      end
    rescue APIError => e
      @workflow_run.update_as_failed(render_error(status: e.status, errorcode: e.errorcode, message: e.message))
    end
  end

  private

  def set_scm_event
    @gitlab_event = request.env['HTTP_X_GITLAB_EVENT']
    @github_event = request.env['HTTP_X_GITHUB_EVENT']
  end

  def validate_scm_event
    return if @gitlab_event.present? || @github_event.present?

    @workflow_run.update_as_failed(
      render_error(
        status: 400,
        errorcode: 'bad_request',
        message: 'Only GitHub and GitLab are supported. Could not find the required HTTP request headers X-GitHub-Event or X-Gitlab-Event.'
      )
    )
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

  def create_workflow_run
    raise Trigger::Errors::InvalidToken, 'Wrong token type. Please use workflow tokens only.' unless @token.is_a?(Token::Workflow)

    request_headers = request.headers.to_h.keys.map { |k| "#{k}: #{request.headers[k]}" if k.match?(/^HTTP_/) }.compact.join("\n")
    @workflow_run = @token.workflow_runs.create(request_headers: request_headers, request_payload: request.body.read)
  end

  def abort_trigger_if_ignored_pull_request_action
    @scm_webhook = TriggerControllerService::ScmExtractor.new(scm, event, payload).call

    render_ok if @scm_webhook && @scm_webhook.ignored_pull_request_action?
  end
end
