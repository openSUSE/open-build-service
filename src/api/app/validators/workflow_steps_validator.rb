class WorkflowStepsValidator < ActiveModel::Validator
  def validate(record)
    @workflow = record

    validate_steps
  end

  private

  def validate_steps
    if @workflow.workflow_steps.blank?
      @workflow.errors.add(:base, 'Workflow steps are not present')
      return
    end

    if @workflow.steps.blank?
      @workflow.errors.add(:base, 'The provided workflow steps are unsupported')
      return
    end

    @workflow.errors.add(:base, unsupported_steps_error_message) if unsupported_steps.present?
    @workflow.errors.add(:base, invalid_steps_error_message) if invalid_steps.present?
  end

  def unsupported_steps
    @unsupported_steps ||= @workflow.workflow_steps.map do |steps|
      rejected_steps = steps.reject { |step_name, _| Workflow::SUPPORTED_STEPS.key?(step_name) }
      rejected_steps.keys
    end.flatten
  end

  def invalid_steps
    @invalid_steps ||= @workflow.steps.reject(&:valid?)
  end

  def unsupported_steps_error_message
    "The following workflow steps are unsupported: #{unsupported_steps.map { |step| "'#{step}'" }.to_sentence}"
  end

  def invalid_steps_error_message
    # TODO: Include the name of the step in this error message.
    "#{invalid_steps.map { |step| step.errors.full_messages }.flatten.to_sentence}"
  end
end
