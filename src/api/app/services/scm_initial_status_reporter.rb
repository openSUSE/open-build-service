class ScmInitialStatusReporter < SCMStatusReporter
  attr_accessor :state

  def initialize(event_payload, event_subscription_payload, scm_token, event_type = nil)
    super(event_payload, event_subscription_payload, scm_token)
    @state = event_type.nil? ? 'pending' : 'success'
  end

  private

  def status_options
    { context: 'OBS SCM/CI Workflow Integration started' }
  end
end
