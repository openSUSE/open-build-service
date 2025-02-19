class Workflow::Step::SetFlags < Workflow::Step
  REQUIRED_KEYS = [:flags].freeze
  REQUIRED_FLAG_KEYS = %i[type status project].freeze
  OPTIONAL_FLAG_KEYS = %i[package repository architecture].freeze

  validate :validate_flags

  def call
    return if workflow_run.closed_merged_pull_request? || workflow_run.reopened_pull_request? || workflow_run.unlabeled_pull_request?
    return unless valid?

    set_flags
  end

  def flags
    step_instructions[:flags]
  end

  private

  def set_flags
    ActiveRecord::Base.transaction do
      objects_to_store = Set.new
      flags.each do |flag|
        main_object = project_or_package(flag)
        Pundit.authorize(token.executor, main_object, :update?)

        architecture_id = Architecture.find_by_name(flag[:architecture]).id if flag[:architecture]
        existing_flag = main_object.flags.find_by(flag: flag[:type], repo: flag[:repository], architecture_id: architecture_id)

        next if existing_flag.present? && existing_flag.status == flag[:status]

        if existing_flag.present?
          existing_flag.update!(status: flag[:status])
        else
          main_object.add_flag(flag[:type], flag[:status], flag[:repository], flag[:architecture])
          main_object.save!
        end
        objects_to_store << main_object
      end

      objects_to_store.each { |main_object| main_object.store(comment: 'SCM/CI integration, set_flags step') }
    end
  end

  def project_or_package(flag)
    project = Project.find_by!(name: target_project_name(project_name: flag[:project]))
    package = project.packages.find_by(name: target_package_name(package_name: flag[:package])) if flag[:package].present?
    package.presence || project
  end

  def validate_flags
    return if flags.all? { |flag| (REQUIRED_FLAG_KEYS - flag.keys).empty? }

    required_flag_keys_sentence ||= REQUIRED_FLAG_KEYS.map { |key| "'#{key}'" }.to_sentence
    errors.add(:base, "set_flags step: All flags must have the #{required_flag_keys_sentence} keys")
  end

  # TODO: Totally duplicated from Workflow::Step. Remove the duplication by using a service instead for all steps depending on this method.
  def target_project_name(project_name:)
    return project_name if workflow_run.push_event? || workflow_run.tag_push_event?

    return nil unless workflow_run.pull_request_event?

    pr_subproject_name = workflow_run.target_repository_full_name&.tr('/', ':')

    "#{project_name}:#{pr_subproject_name}:PR-#{workflow_run.pr_number}"
  end
end
