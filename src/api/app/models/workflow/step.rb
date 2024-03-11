class Workflow::Step
  include ActiveModel::Model
  include WorkflowStepInstrumentation # for run_callbacks

  SHORT_COMMIT_SHA_LENGTH = 7

  validate :validate_required_keys_in_step_instructions
  validate :validate_project_names_in_step_instructions
  validate :validate_package_names_in_step_instructions

  attr_accessor :scm_webhook, :step_instructions, :token, :workflow_run

  def initialize(attributes = {})
    run_callbacks(:initialize) do
      super
      @step_instructions = attributes[:step_instructions]&.deep_symbolize_keys || {}
    end
  end

  def call
    raise AbstractMethodCalled
  end

  protected

  def validate_required_keys_in_step_instructions
    self.class::REQUIRED_KEYS.each do |required_key|
      unless step_instructions.key?(required_key)
        errors.add(:base, "The '#{required_key}' key is missing")
        next
      end

      errors.add(:base, "The '#{required_key}' key must provide a value") if step_instructions[required_key].blank?
    end
  end

  private

  def validate_project_names_in_step_instructions
    %i[project source_project target_project].each do |key_name|
      next unless step_instructions[key_name]
      next if Project.valid_name?(step_instructions[key_name])

      errors.add(:base, "invalid #{key_name}: '#{step_instructions[key_name]}'")
    end
  end

  def validate_package_names_in_step_instructions
    %i[package source_package target_package].each do |key_name|
      next unless step_instructions[key_name]
      next if Package.valid_name?(step_instructions[key_name])

      errors.add(:base, "invalid #{key_name}: '#{step_instructions[key_name]}'")
    end
  end
end
