class Workflow
  include ActiveModel::Model

  SUPPORTED_STEPS = {
    branch_package: Workflow::Step::BranchPackageStep,
    link_package: Workflow::Step::LinkPackageStep,
    configure_repositories: Workflow::Step::ConfigureRepositories,
    rebuild_package: Workflow::Step::RebuildPackage
  }.freeze

  SUPPORTED_FILTERS = [:architectures, :branches, :event, :repositories].freeze

  attr_accessor :workflow_instructions, :scm_webhook, :token, :workflow_run_id

  def initialize(attributes = {})
    super
    @workflow_instructions = attributes[:workflow_instructions].deep_symbolize_keys
  end

  validates_with WorkflowStepsValidator
  validates_with WorkflowFiltersValidator

  def call
    return unless event_matches_event_filter?
    return unless branch_matches_branches_filter?

    case
    when scm_webhook.closed_merged_pull_request?
      destroy_target_projects
    when scm_webhook.reopened_pull_request?
      restore_target_projects
    when scm_webhook.new_pull_request?, scm_webhook.updated_pull_request?, scm_webhook.push_event?, scm_webhook.tag_push_event?
      steps.each do |step|
        step.call({ workflow_filters: filters })
      end
    end
  end

  def steps
    return [] if workflow_steps.blank?

    @steps ||= workflow_steps.each_with_object([]) do |step_definition, steps_array|
      step_definition
        .select { |step_name, _| SUPPORTED_STEPS.key?(step_name) }
        .map { |step_name, step_instructions| initialize_step(step_name, step_instructions) }
        .select { |new_step| steps_array << new_step }
      steps_array
    end
  end

  def filters
    return {} if supported_filters.blank?

    @filters ||= SUPPORTED_FILTERS.index_with do |filter|
      supported_filters[filter]
    end.compact
  end

  def workflow_steps
    @workflow_steps ||= workflow_instructions.fetch(:steps, [])
  end

  private

  def initialize_step(step_name, step_instructions)
    SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions,
                                   scm_webhook: scm_webhook,
                                   token: token)
  end

  def supported_filters
    @supported_filters ||= workflow_instructions.fetch(:filters, {}).select { |key, _value| SUPPORTED_FILTERS.include?(key.to_sym) }
  end

  def event_matches_event_filter?
    return true unless supported_filters.key?(:event)

    case filters[:event]
    when 'push'
      scm_webhook.push_event?
    when 'tag_push'
      scm_webhook.tag_push_event?
    when 'pull_request'
      scm_webhook.pull_request_event?
    else
      false
    end
  end

  def branch_matches_branches_filter?
    return true unless supported_filters.key?(:branches)

    branches_only = filters[:branches].fetch(:only, [])
    branches_ignore = filters[:branches].fetch(:ignore, [])

    return true if branches_only.present? && branches_only.include?(scm_webhook.payload[:target_branch])
    return true if branches_ignore.present? && branches_ignore.exclude?(scm_webhook.payload[:target_branch])

    false
  end

  # TODO: Extract this into a service
  def destroy_target_projects
    # Do not process steps for which there's nothing to do
    processable_steps = steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) || step.instance_of?(::Workflow::Step::RebuildPackage) }
    target_packages = steps.map(&:target_package).uniq.compact
    EventSubscription.where(channel: 'scm', token: self, package: target_packages).delete_all

    target_project_names = processable_steps.map(&:target_project_name).uniq.compact
    # We want the callbacks to run after destroy, so we can't use delete_all
    Project.where(name: target_project_names).destroy_all
  end

  # TODO: Extract this into a service
  def restore_target_projects
    token_user_login = token.user.login

    # Do not process steps for which there's nothing to do
    processable_steps = steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) || step.instance_of?(::Workflow::Step::RebuildPackage) }
    target_project_names = processable_steps.map(&:target_project_name).uniq.compact
    target_project_names.each do |target_project_name|
      Project.restore(target_project_name, user: token_user_login)
    end

    target_packages = processable_steps.map(&:target_package).uniq.compact
    target_packages.each do |target_package|
      # FIXME: We shouldn't rely on a workflow step to be able to create/update subscriptions
      processable_steps.first.create_or_update_subscriptions(target_package, filters)
    end
  end
end
