class Workflow
  include ActiveModel::Model

  SUPPORTED_STEPS = {
    branch_package: Workflow::Step::BranchPackageStep,
    link_package: Workflow::Step::LinkPackageStep,
    configure_repositories: Workflow::Step::ConfigureRepositories,
    rebuild_package: Workflow::Step::RebuildPackage
  }.freeze

  SUPPORTED_FILTERS = [:architectures, :repositories].freeze
  # The order of the filter types determines their precedence
  SUPPORTED_FILTER_TYPES = [:only, :ignore].freeze

  attr_accessor :workflow_instructions, :scm_webhook, :token

  def initialize(attributes = {})
    super
    @workflow_instructions = attributes[:workflow_instructions].deep_symbolize_keys
  end

  validates_with WorkflowStepsValidator
  validates_with WorkflowFiltersValidator

  def call
    case
    when scm_webhook.closed_merged_pull_request?
      destroy_target_projects
    when scm_webhook.reopened_pull_request?
      restore_target_projects
    when scm_webhook.new_pull_request?, scm_webhook.updated_pull_request?
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
    filters = {}

    return filters if supported_filters.blank?

    SUPPORTED_FILTERS.each do |filter|
      SUPPORTED_FILTER_TYPES.each do |filter_type|
        # The filter type might not be present... so in that case, we go to the next
        next unless (filter_values = supported_filters.dig(filter, filter_type))

        filters[filter] = { "#{filter_type}": filter_values }

        # As soon as a supported filter type is present, we get out of the loop since the following filter types have a lower precedence
        break
      end
    end

    filters
  end

  def workflow_steps
    workflow_instructions.fetch(:steps, [])
  end

  private

  def initialize_step(step_name, step_instructions)
    SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions,
                                   scm_webhook: scm_webhook,
                                   token: token)
  end

  def supported_filters
    @supported_filters ||= workflow_instructions[:filters]&.select { |key, _value| SUPPORTED_FILTERS.include?(key.to_sym) }
  end

  def destroy_target_projects
    # Do not process steps for which there's nothing to do
    processable_steps = steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) }
    target_packages = steps.map(&:target_package).uniq.compact
    EventSubscription.where(channel: 'scm', token: self, package: target_packages).delete_all

    target_project_names = processable_steps.map(&:target_project_name).uniq.compact
    # We want the callbacks to run after destroy, so we can't use delete_all
    Project.where(name: target_project_names).destroy_all
  end

  def restore_target_projects
    token_user_login = token.user.login

    # Do not process steps for which there's nothing to do
    processable_steps = steps.reject { |step| step.instance_of?(::Workflow::Step::ConfigureRepositories) }
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
