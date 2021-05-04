class Workflow
  include ActiveModel::Model

  SUPPORTED_EVENTS = %w[pull_request].freeze
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze

  validates :event, inclusion: { in: SUPPORTED_EVENTS, allow_nil: false }

  def initialize(workflow:, scm_extractor_payload:)
    @workflow = workflow
    @scm_extractor_payload = scm_extractor_payload
  end

  def event
    @workflow['filters']['event']
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
