class Workflow
  include ActiveModel::Model
  include WorkflowInstrumentation # for run_callbacks
  include WorkflowVersionMatcher

  SCM_CI_DOCUMENTATION_URL = 'https://openbuildservice.org/help/manuals/obs-user-guide/cha.obs.scm_ci_workflow_integration.html'.freeze

  SUPPORTED_STEPS = {
    branch_package: Workflow::Step::BranchPackageStep, link_package: Workflow::Step::LinkPackageStep,
    configure_repositories: Workflow::Step::ConfigureRepositories, rebuild_package: Workflow::Step::RebuildPackage,
    set_flags: Workflow::Step::SetFlags, trigger_services: Workflow::Step::TriggerServices,
    submit_request: Workflow::Step::SubmitRequest
  }.freeze

  SUPPORTED_FILTERS = %i[branches event].freeze

  attr_accessor :workflow_instructions, :scm_webhook, :token, :workflow_run, :workflow_version_number

  def initialize(attributes = {})
    run_callbacks(:initialize) do
      super
      @workflow_instructions = attributes[:workflow_instructions].deep_symbolize_keys
      @workflow_version_number = attributes[:workflow_version_number]
    end
  end

  validates_with WorkflowStepsValidator
  validates_with WorkflowFiltersValidator
  validates_with WorkflowVersionValidator
  validate :event_supports_branches_filter?, on: :call, if: :event_matches_event_filter?

  def call
    run_callbacks(:call) do
      return unless event_matches_event_filter?
      return unless branch_matches_branches_filter?

      steps.each do |step|
        # ArtifactsCollector can only be called if the step.call doesn't return nil because of a validation error
        step.call && Workflows::ArtifactsCollector.new(step: step, workflow_run_id: workflow_run.id).call
      end
    end
  end

  def event_supports_branches_filter?
    # Tags do not have a reference to a branch, they are referring to a commit
    return false unless @workflow_instructions.dig(:filters, :branches).present? && scm_webhook.tag_push_event?

    errors.add(:filters, 'for branches are not supported for the tag push event. ' \
                         "Documentation for filters: #{WorkflowFiltersValidator::DOCUMENTATION_LINK}")
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
                                   token: token,
                                   workflow_run: workflow_run)
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
    when 'merge_request'
      scm_webhook.pull_request_event? && feature_available_for_workflow_version?(workflow_version: workflow_version_number, feature_name: 'event_aliases')
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
end
