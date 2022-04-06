class WorkflowStepsValidator < ActiveModel::Validator
  DOCUMENTATION_LINK = "#{::Workflow::SCM_CI_DOCUMENTATION_URL}#sec.obs.obs_scm_ci_workflow_integration.setup.obs_workflows.steps".freeze

  def validate(record)
    @workflow = record

    validate_steps

    return unless @workflow.errors.include?(:steps)

    # Guide users by sharing a link whenever there's a validation error
    @workflow.errors.add(:base, "Documentation for steps: #{DOCUMENTATION_LINK}")
  end

  private

  def validate_steps
    if @workflow.workflow_steps.blank?
      @workflow.errors.add(:steps, 'are mandatory in a workflow')
      return
    end

    if @workflow.steps.blank?
      @workflow.errors.add(:steps, 'provided in the workflow are unsupported')
      return
    end

    @workflow.errors.add(:steps, unsupported_steps_error_message) if unsupported_steps.present?
    @workflow.errors.add(:steps, invalid_steps_error_message) if invalid_steps.present?
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
    "#{unsupported_steps.map { |step| "'#{step}'" }.to_sentence} are unsupported"
  end

  def invalid_steps_error_message
    "with errors:\n" +
      invalid_steps.map { |step| "#{Workflow::SUPPORTED_STEPS.key(step.class)} - #{step.errors.full_messages.to_sentence}" }.flatten.to_sentence
  end
end
