class Workflow
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze
  SUPPORTED_FILTERS = [:architectures, :repositories].freeze
  # The order of the filter types determines their precedence
  SUPPORTED_FILTER_TYPES = [:only, :ignore].freeze

  include ActiveModel::Validations
  validates_with WorkflowValidator

  def initialize(workflow:, scm_extractor_payload:, token:)
    @workflow = workflow.with_indifferent_access
    @scm_extractor_payload = scm_extractor_payload
    @token = token

    raise MyNewErrorClass, "Errors in the workflow: #{errors.full_messages.to_sentence}" unless valid?
  end

  def steps
    @steps ||= workflow_steps.each_with_object([]) do |step_definition, acc|
      step_definition
        .select { |step_name, _| SUPPORTED_STEPS.key?(step_name) }
        .map { |step_name, step_instructions| initialize_step(step_name, step_instructions) }
        .select(&:allowed_event_and_action?)
        .select { |new_step| acc << new_step }
      acc
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

  private

  def workflow_steps
    @workflow.fetch('steps', {})
  end

  def initialize_step(step_name, step_instructions)
    SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions,
                                   scm_extractor_payload: @scm_extractor_payload,
                                   token: @token)
  end

  def supported_filters
    @supported_filters ||= @workflow[:filters]&.select { |key, _value| SUPPORTED_FILTERS.include?(key.to_sym) }
  end
end
