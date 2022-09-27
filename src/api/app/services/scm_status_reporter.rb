class SCMStatusReporter
  attr_accessor :event_payload, :event_subscription_payload, :state, :initial_report

  def initialize(event_payload, event_subscription_payload, scm_token, workflow_run = nil, event_type = nil, initial_report: false)
    @event_payload = event_payload.deep_symbolize_keys
    @event_subscription_payload = event_subscription_payload.deep_symbolize_keys
    @scm_token = scm_token
    @workflow_run = workflow_run
    @initial_report = initial_report

    @state = if @initial_report
               event_type.nil? ? 'pending' : 'success'
             else # reports done by the report_to_scm_job
               event_type.nil? ? 'pending' : scm_final_state(event_type)
             end
  end

  def call
    if github?
      GithubStatusReporter.new(@event_payload,
                               @event_subscription_payload,
                               @scm_token,
                               @state,
                               @workflow_run,
                               initial_report: @initial_report).call
    elsif gitlab?
      GitlabStatusReporter.new(@event_payload,
                               @event_subscription_payload,
                               @scm_token,
                               @state,
                               @workflow_run,
                               initial_report: @initial_report).call
    elsif gitea?
      GiteaStatusReporter.new(@event_payload,
                              @event_subscription_payload,
                              @scm_token,
                              @state,
                              @workflow_run,
                              initial_report: @initial_report).call
    end
  end

  def github?
    @event_subscription_payload[:scm] == 'github'
  end

  def gitlab?
    @event_subscription_payload[:scm] == 'gitlab'
  end

  def gitea?
    @event_subscription_payload[:scm] == 'gitea'
  end

  private

  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      'failure'
    when 'Event::BuildSuccess'
      'success'
    else
      'pending'
    end
  end
end
