class WorkflowValidator < ActiveModel::Validator
  # Maybe even split this validator in two: WorkflowStepsValidator and WorkflowFiltersValidator
  def validate(record)
    # validate workflow steps

    # if necessary, validate workflow fitlers (it's possible that filters aren't defined in a workflow)
  end

  private

  def valid_steps?
    unsupported_steps.none? && !invalid_steps?
  end

  def unsupported_steps
    @unsupported_steps ||= workflow_steps.each_with_object([]) do |step_definition, acc|
      rejected_steps = step_definition.reject { |step_name, _| SUPPORTED_STEPS.key?(step_name) }
      rejected_steps.empty? ? acc : acc << rejected_steps
    end
  end

  def invalid_steps?
    record.steps.reject(&:valid?).any?
  end

  # TODO: add errors to errors[:base] -> https://guides.rubyonrails.org/active_record_validations.html#errors-base
  def steps_errors
    unsupported_steps.each_with_object([]) do |step_definition, acc|
      step_definition.each do |step_name, _|
        acc << "'#{step_name}' is not a supported step"
      end
      acc
    end
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
end
