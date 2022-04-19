class ScmInitialStatusReporter < SCMStatusReporter
  attr_accessor :state

  def initialize(event_payload, event_subscription_payload, scm_token, workflow_run, event_type = nil)
    super(event_payload, event_subscription_payload, scm_token, event_type, workflow_run)
    @state = event_type.nil? ? 'pending' : 'success'
    @workflow_run = workflow_run
  end

  private

  def status_options
    { context: 'OBS SCM/CI Workflow Integration started',
      target_url: Rails.application.routes.url_helpers.token_workflow_run_url(@workflow_run.token_id, @workflow_run.id, host: Configuration.obs_url) }
  end
end
