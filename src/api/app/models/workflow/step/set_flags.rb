class Workflow::Step::SetFlags < Workflow::Step
  REQUIRED_KEYS = [:flags].freeze
  REQUIRED_FLAG_KEYS = [:type, :status, :project].freeze
  OPTIONAL_FLAG_KEYS = [:package, :repository, :architecture].freeze

  validate :validate_flags

  def call
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
        main_object.save!
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

  # TODO: Totally duplicated from Workflow::Step. Remove the duplication by using a service instead for all steps depending on this method.
  def target_project_name(project_name:)
    return project_name if scm_webhook.push_event? || scm_webhook.tag_push_event?

    return nil unless scm_webhook.pull_request_event?

    pr_subproject_name = if scm_webhook.payload[:scm] == 'github'
                           scm_webhook.payload[:target_repository_full_name]&.tr('/', ':')
                         else
                           scm_webhook.payload[:path_with_namespace]&.tr('/', ':')
                         end

    "#{project_name}:#{pr_subproject_name}:PR-#{scm_webhook.payload[:pr_number]}"
  end

  # TODO: Totally duplicated from Workflow::Step. Remove the duplication by using a service instead for all steps depending on this method.
  def target_package_name(package_name:, short_commit_sha: false)
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
end
