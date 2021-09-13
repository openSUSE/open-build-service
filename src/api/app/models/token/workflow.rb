class Token::Workflow < Token
  validates :scm_token, presence: true

  def self.token_name
    'workflow'
  end

  def call(options)
    raise ArgumentError, 'A payload is required' if options[:payload].nil?

    scm_webhook = TriggerControllerService::ScmExtractor.new(options[:scm], options[:event], options[:payload]).call
    return unless scm_webhook.valid?

    yaml_file = Workflows::YAMLDownloader.new(scm_webhook.payload, token: self).call
    workflows = Workflows::YAMLToWorkflowsService.new(yaml_file: yaml_file, scm_webhook: scm_webhook, token: self).call

    case
    when scm_webhook.closed_merged_pull_request?
      destroy_target_projects(workflows)
    when scm_webhook.reopened_pull_request?
      restore_target_projects(workflows)
    when scm_webhook.new_pull_request?, scm_webhook.updated_pull_request?
      call_steps(workflows)
    end
  rescue Octokit::Unauthorized, Gitlab::Error::Unauthorized => e
    raise Token::Errors::SCMTokenInvalid, e.message
  end

  private

  def destroy_target_projects(workflows)
    workflows.each do |workflow|
      # Do not process steps for which there's nothing to do
      workflow_steps = workflow.steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) }
      target_packages = workflow_steps.map(&:target_package).uniq.compact
      delete_subscriptions(target_packages)

      target_project_names = workflow_steps.map(&:target_project_name).uniq.compact
      destroy_all_target_projects(target_project_names)
    end
  end

  # We want the callbacks to run after destroy, so we can't use delete_all
  def destroy_all_target_projects(target_project_names)
    Project.where(name: target_project_names).destroy_all
  end

  def delete_subscriptions(packages)
    EventSubscription.where(channel: 'scm', token: self, package: packages).delete_all
  end

  def restore_target_projects(workflows)
    token_user_login = user.login

    workflows.each do |workflow|
      # Do not process steps for which there's nothing to do
      workflow_steps = workflow.steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) }
      target_project_names = workflow_steps.map(&:target_project_name).uniq.compact
      target_project_names.each do |target_project_name|
        Project.restore(target_project_name, user: token_user_login)
      end

      target_packages = workflow_steps.map(&:target_package).uniq.compact
      target_packages.each do |target_package|
        # FIXME: We shouldn't rely on a workflow step to be able to create/update subscriptions
        workflow_steps.first.create_or_update_subscriptions(target_package, workflow.filters)
      end
    end
  end

  def call_steps(workflows)
    workflows.each do |workflow|
      workflow.steps.each do |step|
        step.call({ workflow_filters: workflow.filters })
      end
    end
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  scm_token  :string(255)      indexed
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
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
