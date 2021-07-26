class Workflow::Step
  include ActiveModel::Model

  validates :source_project_name, presence: true

  attr_reader :scm_extractor_payload, :step_instructions, :token

  # Overwriting the initializer is needed to set `with_indifferent_access`
  def initialize(scm_extractor_payload:, step_instructions:, token:)
    @step_instructions = step_instructions&.with_indifferent_access || {}
    @scm_extractor_payload = scm_extractor_payload&.with_indifferent_access || {}
    @token = token
  end

  def call(_options)
    raise AbstractMethodCalled
  end

  protected

  def source_project_name
    step_instructions['source_project']
  end

  def target_project_name
    "home:#{@token.user.login}:#{source_project_name}:PR-#{scm_extractor_payload[:pr_number]}"
  end
end
