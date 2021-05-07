class Workflow
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze

  def initialize(workflow:, scm_extractor_payload:)
    @workflow = workflow
    @scm_extractor_payload = scm_extractor_payload
  end

  def steps
    steps = []

    @workflow['steps'].each do |step|
      step.each do |step_name, step_instructions|
        next if SUPPORTED_STEPS[step_name].blank?

        new_step = SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions, scm_extractor_payload: @scm_extractor_payload)
        steps << new_step if new_step.allowed_event_and_action?
      end
    end
    steps
  end
end
