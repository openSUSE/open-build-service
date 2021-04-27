class Workflow
  include ActiveModel::Model

  SUPPORTED_EVENTS = %w[pull_request].freeze
  SUPPORTED_STEPS = { 'branch_package' => Workflow::Step::BranchPackageStep }.freeze

  validates :event, inclusion: { in: SUPPORTED_EVENTS, allow_nil: false }

  def initialize(workflow:, pr_number:)
    @workflow = workflow
    @pr_number = pr_number
  end

  def event
    @workflow['filters']['event']
  end

  def steps
    steps = []

    @workflow['steps'].each do |step|
      step.each do |step_name, step_instructions|
        steps << SUPPORTED_STEPS[step_name].new(step_instructions: step_instructions, pr_number: @pr_number)
      end
    end
    steps
  end
end
