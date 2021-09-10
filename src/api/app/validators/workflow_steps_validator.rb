class WorkflowStepsValidator < ActiveModel::Validator
  def validate(record)
    @workflow = record

    valid_steps?
  end

  private

  def valid_steps?
    @workflow.errors.add(:base, 'Invalid workflow. Steps are not present.') if no_steps?
    @workflow.errors.add(:base, "Invalid workflow step definition: #{errors.to_sentence}") if unsupported_steps.present? || invalid_steps.present?
  end

  def unsupported_steps
    @workflow.workflow_steps.each_with_object([]) do |step_definition, acc|
      rejected_steps = step_definition.reject { |step_name, _| Workflow::SUPPORTED_STEPS.key?(step_name) }
      rejected_steps.empty? ? acc : acc << rejected_steps
    end
  end

  def invalid_steps
    @workflow.steps.reject(&:valid?)
  end

  def no_steps?
    @workflow.workflow_steps.blank? || @workflow.steps.blank?
  end

  def errors
    error_messages = []
    step_names = []
    unsupported_steps.each do |step_definition|
      step_definition.each do |step_name, _|
        step_names << step_name
      end
    end

    if step_names.size.positive?
      error_messages << "#{step_names.to_sentence} #{step_names.size > 1 ? 'are not supported steps' : 'is not a supported step'}"
    end

    invalid_steps.each do |step|
      error_messages << step.errors.full_messages
    end
    error_messages.flatten
  end
end
