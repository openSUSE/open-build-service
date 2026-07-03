class Token::Workflow < Token
  AUTHENTICATION_DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.token_authentication.how_to_authenticate_scm_with_obs".freeze

  has_many :workflow_runs, dependent: :destroy, foreign_key: 'token_id', inverse_of: false
  has_and_belongs_to_many :users,
                          join_table: :workflow_token_users,
                          foreign_key: :token_id,
                          association_foreign_key: :user_id,
                          dependent: :destroy,
                          after_add: ->(token, user) { Event::TokenMembershipUpdate.create(token_id: token.id, user_login: user.login, who: User.session&.login, action: 'share') },
                          after_remove: ->(token, user) { Event::TokenMembershipUpdate.create(token_id: token.id, user_login: user.login, who: User.session&.login, action: 'unshare') },
                          inverse_of: :users
  has_and_belongs_to_many :groups,
                          join_table: :workflow_token_groups,
                          foreign_key: :token_id,
                          association_foreign_key: :group_id,
                          dependent: :destroy,
                          after_add: ->(token, group) { Event::TokenMembershipUpdate.create(token_id: token.id, group_title: group.title, who: User.session&.login, action: 'share') },
                          after_remove: ->(token, group) { Event::TokenMembershipUpdate.create(token_id: token.id, group_title: group.title, who: User.session&.login, action: 'unshare') },
                          inverse_of: :groups

  attr_writer :reason

  validates :scm_token, presence: true
  # Either a url referring to the worklflow configuration file or a filepath to the config inside the
  # SCM repository has to be provided
  validates :workflow_configuration_path, presence: true, unless: -> { workflow_configuration_url.present? }
  validates :workflow_configuration_url, presence: true, unless: -> { workflow_configuration_path.present? }

  after_save :state_change_event, if: :enabled_previously_changed?

  def call(workflow_run)
    set_triggered_at
    # FIXME: This makes little sense, wherever we use response_url, just use api_endpoint...
    workflow_run.update(response_url: workflow_run.api_endpoint)

    # In a ping event we just return early after the validation and the initial report to SCM
    if workflow_run.ping_event?
      ReportToSCMJob.perform_later(workflow_run: workflow_run, event_type: 'success', initial_report: true)
      return []
    end
    yaml_file = Workflows::YAMLDownloader.new(workflow_run, token: self).call
    if yaml_file.failure?
      if yaml_file.error == :not_found
        workflow_run.update(status: :skipped,
                            response_body: "No workflow configuration found on branch '#{workflow_run.target_branch}'. Skipping.")
        return []
      end
      raise Token::Errors::NonExistentWorkflowsFile, yaml_file.error
    end

    @workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file.value, token: self, workflow_run: workflow_run).call

    return validation_errors unless validation_errors.none?

    # Initial report with status set to pending
    ReportToSCMJob.perform_later(workflow_run: workflow_run, initial_report: true)
    @workflows.each do |workflow|
      return workflow.errors.full_messages if workflow.invalid?(:call)

      workflow.call
    end
    # Final status report
    ReportToSCMJob.perform_later(workflow_run: workflow_run, event_type: 'success', initial_report: true)
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

  def state_change_event
    Event::TokenStateChange.create(id: workflow_runs.last&.id, token_id: id, reason: @reason, enabled: enabled)
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
#  string                      :string(255)      uniquely indexed
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
