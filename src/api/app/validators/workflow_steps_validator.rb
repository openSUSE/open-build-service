class WorkflowStepsValidator < ActiveModel::Validator
  def validate(record)
    @scm_extractor_payload = record.scm_extractor_payload
    @workflow = record

    valid_steps?
  end

  private

  def valid_steps?
    raise Token::Errors::InvalidWorkflowStepDefinition, 'Invalid workflow. Steps are not present.' if no_steps?
    raise Token::Errors::InvalidWorkflowStepDefinition, "Invalid workflow step definition: #{errors.to_sentence}" if
      unsupported_steps.present? || invalid_steps.present?
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
    acc = []
    unsupported_steps.each do |step_definition|
      step_definition.each do |step_name, _|
        acc << "'#{step_name}' is not a supported step"
      end
    end
    invalid_steps.each do |step|
      acc << step.errors.full_messages.to_sentence
    end
    acc
  end
end
