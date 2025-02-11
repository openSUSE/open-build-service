class SCMStatusReporter
  attr_accessor :event_payload, :event_subscription_payload, :state, :initial_report

  EVENT_ACTIONS_TO_SKIP = %w[closed close merge].freeze
  REPORTERS = {
    'github' => GithubStatusReporter,
    'gitlab' => GitlabStatusReporter,
    'gitea' => GiteaStatusReporter
  }.freeze

  def initialize(event_payload:, event_subscription_payload:, scm_token:, workflow_run: nil, event_type: nil, initial_report: false)
    @event_payload = event_payload.deep_symbolize_keys
    @event_subscription_payload = event_subscription_payload.deep_symbolize_keys
    @scm_token = scm_token
    @workflow_run = workflow_run
    @initial_report = initial_report
    @event_type = event_type

    @state = if @initial_report
               event_type.nil? ? 'pending' : 'success'
             else # reports done by the report_to_scm_job
               event_type.nil? ? 'pending' : scm_final_state(event_type)
             end
  end

  def call
    return if EVENT_ACTIONS_TO_SKIP.include?(@event_payload[:action])

    REPORTERS[@workflow_run.scm_vendor].new(@event_payload,
                                            @event_subscription_payload,
                                            @scm_token,
                                            @state,
                                            @workflow_run,
                                            @event_type,
                                            initial_report: @initial_report).call
  end

  private

  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      'failure'
    when 'Event::BuildSuccess'
      'success'
    when 'Event::RequestStatechange'
      return 'success' if @event_payload[:state] == 'accepted'
      return 'failure' if %w[declined superseded revoked].include?(@event_payload[:state])

      'pending'
    else
      'pending'
    end
  end
end
