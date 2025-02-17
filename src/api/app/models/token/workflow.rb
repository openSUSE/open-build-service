class Token::Workflow < Token
  AUTHENTICATION_DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.token_authentication.how_to_authenticate_scm_with_obs".freeze

  has_many :workflow_runs, dependent: :destroy, foreign_key: 'token_id', inverse_of: false
  has_and_belongs_to_many :users,
                          join_table: :workflow_token_users,
                          foreign_key: :token_id,
                          association_foreign_key: :user_id,
                          dependent: :destroy,
                          inverse_of: :users
  has_and_belongs_to_many :groups,
                          join_table: :workflow_token_groups,
                          foreign_key: :token_id,
                          association_foreign_key: :group_id,
                          dependent: :destroy,
                          inverse_of: :groups

  validates :scm_token, presence: true
  # Either a url referring to the worklflow configuration file or a filepath to the config inside the
  # SCM repository has to be provided
  validates :workflow_configuration_path, presence: true, unless: -> { workflow_configuration_url.present? }
  validates :workflow_configuration_url, presence: true, unless: -> { workflow_configuration_path.present? }

  def call(options)
    set_triggered_at
    workflow_run = options[:workflow_run]
    # FIXME: This makes little sense, wherever we use response_url, just use api_endpoint...
    workflow_run.update(response_url: workflow_run.api_endpoint)

    # We return early with a ping event, since it doesn't make sense to perform payload checks with it, just respond
    if workflow_run.ping_event?
      SCMStatusReporter.new(event_payload: workflow_run.payload, event_subscription_payload: workflow_run.payload, scm_token: scm_token, workflow_run: workflow_run, event_type: 'success', initial_report: true).call
      return []
    end
    yaml_file = Workflows::YAMLDownloader.new(workflow_run, token: self).call
    @workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, token: self, workflow_run: workflow_run).call

    return validation_errors unless validation_errors.none?

    # This is just an initial generic report to give a feedback asap. Initial status pending
    SCMStatusReporter.new(event_payload: workflow_run.payload, event_subscription_payload: workflow_run.payload, scm_token: scm_token, workflow_run: workflow_run, initial_report: true).call
    @workflows.each do |workflow|
      return workflow.errors.full_messages if workflow.invalid?(:call)

      workflow.call
    end
    SCMStatusReporter.new(event_payload: workflow_run.payload, event_subscription_payload: workflow_run.payload, scm_token: scm_token, workflow_run: workflow_run, event_type: 'success', initial_report: true).call
    # Always returning validation errors to report them back to the SCM in order to help users debug their workflows
    validation_errors
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized
    raise Token::Errors::SCMTokenInvalid, "Your SCM token secret is not properly set in your OBS workflow token.\nCheck #{AUTHENTICATION_DOCUMENTATION_LINK}"
  end

  def owned_by?(some_user)
    # TODO: remove the first condition if we migrate, with a data migration, the Token.executor to Token.users
    executor == some_user || users.include?(some_user) || groups.map(&:users).flatten.include?(some_user)
  end

  def workflow_configuration_path_default?
    workflow_configuration_path == '.obs/workflows.yml'
  end

  def members
    # exctract all the users and groups members the token is shared with,
    # and merge them all together in a single set removing nils and duplicated entries
    [users, groups&.map(&:users)&.flatten].flatten.compact.uniq
  end

  private

  def validation_errors
    @validation_errors ||= begin
      error_messages = []

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
#  id                          :integer          not null, primary key
#  description                 :string(64)       default("")
#  enabled                     :boolean          default(TRUE), not null, indexed
#  scm_token                   :string(255)      indexed
#  string                      :string(255)      indexed
#  triggered_at                :datetime
#  type                        :string(255)
#  workflow_configuration_path :string(255)      default(".obs/workflows.yml")
#  workflow_configuration_url  :string(8192)
#  executor_id                 :integer          not null, indexed
#  package_id                  :integer          indexed
#
# Indexes
#
#  index_tokens_on_enabled    (enabled)
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (executor_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (executor_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
