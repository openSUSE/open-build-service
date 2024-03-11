class Workflow::Step::SetFlags < Workflow::Step
  include WorkflowStepTargetObjects

  REQUIRED_KEYS = [:flags].freeze
  REQUIRED_FLAG_KEYS = %i[type status project].freeze
  OPTIONAL_FLAG_KEYS = %i[package repository architecture].freeze

  validate :validate_flags

  def call
    return if scm_webhook.closed_merged_pull_request? || scm_webhook.reopened_pull_request?
    return unless valid?

    set_flags
  end

  def flags
    step_instructions[:flags]
  end

  private

  def set_flags
    ActiveRecord::Base.transaction do
      flags.each do |flag|
        main_object = project_or_package(flag)
        check_access(main_object)
        architecture_id = Architecture.find_by_name(flag[:architecture]).id if flag[:architecture]
        existing_flag = main_object.flags.find_by(flag: flag[:type], repo: flag[:repository], architecture_id: architecture_id)

        # We have to update the flag status if the flag already exist and only the status differs
        existing_flag.update!(status: flag[:status]) if existing_flag.present? && existing_flag.status != flag[:status]
        next if existing_flag.present?

        main_object.add_flag(flag[:type], flag[:status], flag[:repository], flag[:architecture])
        main_object.store
      end
    end
  end

  def project_or_package(flag)
    project = Project.find_by!(name: target_project_name(project_name: flag[:project]))
    package = project.packages.find_by(name: target_package_name(package_name: flag[:package])) if flag[:package].present?
    package.presence || project
  end

  def check_access(object)
    raise Pundit::NotAuthorizedError unless Pundit.policy(token.executor, object).update?
  end

  def validate_flags
    return if flags.all? { |flag| (REQUIRED_FLAG_KEYS - flag.keys).empty? }

    required_flag_keys_sentence ||= REQUIRED_FLAG_KEYS.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "set_flags step: All flags must have the #{required_flag_keys_sentence} keys")
  end
end
