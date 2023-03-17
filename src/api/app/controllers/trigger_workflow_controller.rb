class TriggerWorkflowController < TriggerController
  # We don't need to validate that the body of the request is XML. We receive JSON
  skip_before_action :validate_xml_request, :set_project_name, :set_package_name, :set_project, :set_package, :set_object_to_authorize, :set_multibuild_flavor

  before_action :set_scm_event
  before_action :set_scm_extractor
  before_action :extract_scm_webhook
  before_action :create_workflow_run
  before_action :validate_scm_event

  def create
    authorize @token, :trigger?
    @token.executor.run_as do
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
    # Gitea contains the Github headers as well, so we have to check that the Gitea ones are
    # not present for Github
    @github_event = request.env['HTTP_X_GITHUB_EVENT'] unless request.env['HTTP_X_GITEA_EVENT']
    @gitea_event = request.env['HTTP_X_GITEA_EVENT']
  end

  def set_scm_extractor
    scm = if @gitlab_event
            'gitlab'
          elsif @github_event
            'github'
          elsif @gitea_event
            'gitea'
          end
    event = @github_event || @gitlab_event || @gitea_event

    @scm_extractor = TriggerControllerService::SCMExtractor.new(scm, event, payload)
  end

  def validate_scm_event
    return if @scm_extractor.valid?

    @workflow_run.update_as_failed(
      render_error(
        status: 400,
        errorcode: 'bad_request',
        message: @scm_extractor.error_message
      )
    )
  end

  def payload
    request_body = request.body.read
    raise BadSCMPayload if request_body.blank?

    begin
      JSON.parse(request_body)
    rescue JSON::ParserError
      raise BadSCMPayload
    end
  end

  def create_workflow_run
    raise Trigger::Errors::InvalidToken, 'Wrong token type. Please use workflow tokens only.' unless @token.is_a?(Token::Workflow)

    request_headers = request.headers.to_h.keys.map { |k| "#{k}: #{request.headers[k]}" if k.match?(/^HTTP_/) }.compact.join("\n")
    @workflow_run = @token.workflow_runs.create(request_headers: request_headers, request_payload: request.body.read)
  end

  def extract_scm_webhook
    @scm_webhook = @scm_extractor.call

    # There are plenty of different pull/merge request and push events which we don't support.
    # Those should not cause an error, we simply ignore them.
    render_ok if @scm_webhook && (@scm_webhook.ignored_pull_request_action? || @scm_webhook.ignored_push_event?)
  end
end
