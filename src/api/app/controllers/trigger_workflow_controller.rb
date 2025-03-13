class TriggerWorkflowController < ApplicationController
  include ScmWebhookHeadersDataExtractor
  include Trigger::Errors

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login
  # SCMs like GitLab/GitHub send data as parameters which are not strings (e.g.: GitHub - PR number is a integer, GitLab - project is a hash)
  # Other SCMs might also do this, so we're not validating parameters.
  skip_before_action :validate_params
  # We don't need to validate that the body of the request is valid XML. We receive JSON...
  skip_before_action :validate_xml_request

  before_action :set_token
  before_action :validate_token_type
  before_action :check_token_enabled

  def create
    authorize @token, :trigger?

    @workflow_run = @token.workflow_runs.new(request_headers: request_headers,
                                             request_payload: request.body.read,
                                             workflow_configuration_path: @token.workflow_configuration_path,
                                             workflow_configuration_url: @token.workflow_configuration_url,
                                             scm_vendor: scm_vendor,
                                             hook_event: hook_event)

    if @workflow_run.save
      call_token
    # Ignore actions and events we do not support
    elsif @workflow_run.errors[:hook_action].any? || @workflow_run.errors[:hook_event].any?
      render_ok(data: { info: @workflow_run.errors.full_messages.to_sentence })
    else
      render_error(status: 400, message: @workflow_run.errors.full_messages.to_sentence)
    end
  end

  private

  def set_token
    @token = ::TriggerControllerService::TokenExtractor.new(request).call
    raise InvalidToken, 'No valid token found' unless @token
  end

  def pundit_user
    @token.executor
  end

  def validate_token_type
    raise Trigger::Errors::InvalidToken, 'Wrong token type. Please use workflow tokens only.' unless @token.is_a?(Token::Workflow)
  end

  def check_token_enabled
    raise Trigger::Errors::NotEnabledToken, 'This token is not enabled.' unless @token.enabled
  end

  def request_headers
    request.headers.to_h.keys.filter_map do |k|
      "#{k}: #{request.headers[k]}" if k.match?(/^HTTP_/)
    end.join("\n")
  end

  def call_token
    @token.executor.run_as do
      validation_errors = @token.call(workflow_run: @workflow_run)

      unless @workflow_run.status == 'fail' # The SCMStatusReporter might already set the status to 'fail', lets not overwrite it
        if validation_errors.none?
          @workflow_run.update(status: 'success', response_body: render_ok)
        else
          @workflow_run.update_as_failed(render_error(status: 400, message: validation_errors.to_sentence))
        end
      end
    # We always want to return 200 in the request. Because a lot of things in `Workflow`` can go wrong outside this request cycle.
    # People need to have a look at their `WorkflowRun` to see how `Workflow` went.
    rescue APIError => e
      @workflow_run.update_as_failed(render_error(status: e.status, errorcode: e.errorcode, message: e.message))
    rescue Pundit::NotAuthorizedError => e
      @workflow_run.update_as_failed(e.message)
    end
  end
end
