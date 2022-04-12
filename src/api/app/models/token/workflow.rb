class Token::Workflow < Token
  AUTHENTICATION_DOCUMENTATION_LINK = (::Workflow::SCM_CI_DOCUMENTATION_URL +
                                       '#sec.obs.obs_scm_ci_workflow_integration.setup.token_authentication.how_to_authenticate_scm_with_obs').freeze

  has_many :workflow_runs, dependent: :destroy, foreign_key: 'token_id', inverse_of: false

  validates :scm_token, presence: true

  def call(options)
    set_triggered_at
    @scm_webhook = options[:scm_webhook]
    workflow_run = options[:workflow_run]
    raise Token::Errors::MissingPayload, 'A payload is required' if @scm_webhook.payload.blank?

    workflow_run.update(response_url: @scm_webhook.payload[:api_endpoint])
    yaml_file = Workflows::YAMLDownloader.new(@scm_webhook.payload, token: self).call
    @workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: @scm_webhook, token: self, workflow_run: workflow_run).call

    return validation_errors unless validation_errors.none?

    # This is just an initial generic report to give a feedback asap. Initial status pending
    ScmInitialStatusReporter.new(@scm_webhook.payload, @scm_webhook.payload, scm_token, workflow_run).call
    @workflows.each(&:call)
    ScmInitialStatusReporter.new(@scm_webhook.payload, @scm_webhook.payload, scm_token, workflow_run, 'success').call

    # Always returning validation errors to report them back to the SCM in order to help users debug their workflows
    validation_errors
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized
    raise Token::Errors::SCMTokenInvalid, "Your SCM token secret is not properly set in your OBS workflow token.\nCheck #{AUTHENTICATION_DOCUMENTATION_LINK}"
  end

  private

  def validation_errors
    @validation_errors ||= begin
      error_messages = []

      error_messages << @scm_webhook.errors.full_messages unless @scm_webhook.valid?
      @workflows.each do |workflow|
        error_messages << workflow.errors.full_messages unless workflow.valid?
      end

      error_messages.flatten
    end
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id           :integer          not null, primary key
#  description  :string(64)       default("")
#  scm_token    :string(255)      indexed
#  string       :string(255)      indexed
#  triggered_at :datetime
#  type         :string(255)
#  package_id   :integer          indexed
#  user_id      :integer          not null, indexed
#
# Indexes
#
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
