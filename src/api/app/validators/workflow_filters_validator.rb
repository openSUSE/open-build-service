class WorkflowFiltersValidator < ActiveModel::Validator
  def validate(record)
    @workflow = record
    @workflow_instructions = record.workflow_instructions

    valid_filters?
  end

  private

  def valid_filters?
    # Filters aren't mandatory in a workflow
    return unless @workflow_instructions.key?(:filters)

    if unsupported_filters.present?
      @workflow.errors.add(:base,
                           "Unsupported filters: #{unsupported_filters.keys.to_sentence}")
    end

    return unless unsupported_filter_types?

    @workflow.errors.add(:base,
                         "Filters #{unsupported_filter_types.to_sentence} have unsupported keys, #{Workflow::SUPPORTED_FILTER_TYPES.to_sentence} are the only supported keys")
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
