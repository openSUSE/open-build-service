class Token::Workflow < Token
  has_many :workflow_runs, dependent: :destroy, foreign_key: 'token_id', inverse_of: false

  validates :scm_token, presence: true

  def self.token_name
    'workflow'
  end

  def call(options)
    set_triggered_at
    @scm_webhook = options[:scm_webhook]

    raise Token::Errors::MissingPayload, 'A payload is required' if @scm_webhook.payload.blank?

    options[:workflow_run].update(response_url: @scm_webhook.payload[:api_endpoint])
    yaml_file = Workflows::YAMLDownloader.new(@scm_webhook.payload, token: self).call
    @workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: @scm_webhook, token: self, workflow_run_id: options[:workflow_run].id).call

    @workflows.each(&:call) if validation_errors.none?

    # Always returning validation errors to report them back to the SCM in order to help users debug their workflows
    validation_errors
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized => e
    raise Token::Errors::SCMTokenInvalid, e.message
  end

  # Only used by rebuild steps
  def package_find_options
    { use_source: false, follow_project_links: true, follow_multibuild: true }
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
#  name         :string(64)       default("")
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
