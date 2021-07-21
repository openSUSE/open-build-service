class WorkflowFiltersValidator < ActiveModel::Validator
  def validate(record)
    @scm_extractor_payload = record.scm_extractor_payload
    @workflow_instructions = record.workflow_instructions.with_indifferent_access

    valid_filters?
  end

  private

  def valid_filters?
    # Filters aren't mandatory in a workflow
    return unless @workflow_instructions.key?(:filters)

    raise Workflow::Errors::UnsupportedWorkflowFilters, "Unsupported filters: #{unsupported_filters.keys.to_sentence}" if unsupported_filters.present?

    return unless unsupported_filter_types?

    raise Workflow::Errors::UnsupportedWorkflowFilterTypes,
          "Filters #{unsupported_filter_types.to_sentence} have unsupported keys. #{Workflow::SUPPORTED_FILTER_TYPES.to_sentence} are the only supported keys."
  end

  def unsupported_filters
    @workflow_instructions[:filters].select { |key, _value| Workflow::SUPPORTED_FILTERS.exclude?(key.to_sym) }
  end

  def unsupported_filter_types?
    unsupported_filter_types.present?
  end

  def unsupported_filter_types
    unsupported_filter_types = []

    @workflow_instructions[:filters].each do |filter, value|
      unsupported_filter_types << filter unless value.keys.all? { |filter_type| Workflow::SUPPORTED_FILTER_TYPES.include?(filter_type.to_sym) }
    end
    unsupported_filter_types
  end
end
