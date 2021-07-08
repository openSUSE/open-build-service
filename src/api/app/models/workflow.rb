class Workflow
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze

  def initialize(workflow:, scm_extractor_payload:, token:)
    @workflow = workflow
    @scm_extractor_payload = scm_extractor_payload
    @token = token
    raise Token::Errors::InvalidWorkflowStepDefinition, "Invalid workflow step definition: #{errors.to_sentence}" unless
      valid?
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
end
