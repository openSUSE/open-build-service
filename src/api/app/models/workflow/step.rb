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

  def target_project
    Project.find_by(name: target_project_name)
  end

  def target_project_name
    return target_project_base_name if scm_webhook.push_event? || scm_webhook.tag_push_event?

    return nil unless scm_webhook.pull_request_event?

    pr_subproject_name = scm_webhook.payload[:target_repository_full_name]&.tr('/', ':')

    "#{target_project_base_name}:#{pr_subproject_name}:PR-#{scm_webhook.payload[:pr_number]}"
  end

  def target_package
    Package.get_by_project_and_name(target_project_name, target_package_name, follow_multibuild: true)
  rescue Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError
    # We rely on Package.get_by_project_and_name since it's the only way to work with multibuild packages.
    # It's possible for a package to not exist, so we simply rescue and do nothing. The package will be created later in the step.
  end

  def target_package_name(short_commit_sha: false)
    package_name = step_instructions[:target_package] || step_instructions[:source_package]

    case
    when scm_webhook.pull_request_event?
      package_name
    when scm_webhook.push_event?
      commit_sha = scm_webhook.payload[:commit_sha]
      if short_commit_sha
        "#{package_name}-#{commit_sha.slice(0, SHORT_COMMIT_SHA_LENGTH)}"
      else
        "#{package_name}-#{commit_sha}"
      end
    when scm_webhook.tag_push_event?
      "#{package_name}-#{scm_webhook.payload[:tag_name]}"
    end
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

  def target_project_base_name
    raise AbstractMethodCalled
  end

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
