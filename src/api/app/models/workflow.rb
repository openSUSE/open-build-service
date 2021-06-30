class Workflow
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze
  SUPPORTED_FILTERS = [:architectures, :repositories].freeze
  # The order of the filter types determines their precedence
  SUPPORTED_FILTER_TYPES = [:only, :ignore].freeze

  def initialize(workflow:, scm_extractor_payload:, token:)
    @workflow = workflow.with_indifferent_access
    @scm_extractor_payload = scm_extractor_payload
    @token = token

    raise Token::Errors::InvalidWorkflowStepDefinition, "Invalid workflow step definition: #{errors.to_sentence}" unless
      valid?

    # Filters aren't mandatory in a workflow
    return unless @workflow.key?(:filters)

    raise Token::Errors::UnsupportedWorkflowFilters, "Unsupported filters: #{@unsupported_filters.keys.to_sentence}" if unsupported_filters?

    return unless unsupported_filter_types?

    raise Token::Errors::UnsupportedWorkflowFilterTypes,
          "Filters #{@unsupported_filter_types.to_sentence} have unsupported keys. #{SUPPORTED_FILTER_TYPES.to_sentence} are the only supported keys."
  end

  def valid?
    unsupported_steps.none? && !invalid_steps?
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

  def errors
    unsupported_steps.each_with_object([]) do |step_definition, acc|
      step_definition.each do |step_name, _|
        acc << "'#{step_name}' is not a supported step"
      end
      acc
    end
  end

  private

  def invalid_steps?
    steps.reject(&:valid?).any?
  end

  def workflow_steps
    @workflow.fetch('steps', {})
  end

  def unsupported_steps
    @unsupported_steps ||= workflow_steps.each_with_object([]) do |step_definition, acc|
      rejected_steps = step_definition.reject { |step_name, _| SUPPORTED_STEPS.key?(step_name) }
      rejected_steps.empty? ? acc : acc << rejected_steps
    end
  end

  def initialize_step(step_name, step_instructions)
    SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions,
                                   scm_extractor_payload: @scm_extractor_payload,
                                   token: @token)
  end

  def unsupported_filters?
    @unsupported_filters ||= @workflow[:filters].select { |key, _value| SUPPORTED_FILTERS.exclude?(key.to_sym) }

    @unsupported_filters.present?
  end

  def unsupported_filter_types?
    @unsupported_filter_types = []

    @workflow[:filters].each do |filter, value|
      @unsupported_filter_types << filter unless value.keys.all? { |filter_type| SUPPORTED_FILTER_TYPES.include?(filter_type.to_sym) }
    end

    @unsupported_filter_types.present?
  end

  def supported_filters
    @supported_filters ||= @workflow[:filters]&.select { |key, _value| SUPPORTED_FILTERS.include?(key.to_sym) }
  end
end
