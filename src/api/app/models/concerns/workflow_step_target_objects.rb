module WorkflowStepTargetObjects
  extend ActiveSupport::Concern

  private

  def target_project
    Project.find_or_initialize_by(name: target_project_name)
  end

  def target_project_name(project_name: nil)
    target_project_base_name = project_name || step_instructions[:target_project] || step_instructions[:project]

    return target_project_base_name if scm_webhook.push_event? || scm_webhook.tag_push_event?
    return target_project_base_name unless scm_webhook.pull_request_event?

    subproject_name = scm_webhook.payload[:repository_name]&.tr('/', ':')

    "#{target_project_base_name}:#{subproject_name}:PR-#{scm_webhook.payload[:pr_number]}"
  end

  def create_target_project
    return unless target_project.new_record?

    target_project.relationships.build(user: User.session!, role: Role.find_by_title('maintainer'))
    target_project.commit_user = User.session!
    target_project.store
  end

  def authorize_target_project
    auth_action = target_project.new_record? ? :create? : :update?
    Pundit.authorize(@token.executor, target_project, auth_action)
  end

  def target_package
    Package.get_by_project_and_name(target_project_name, target_package_name, follow_multibuild: true)
  rescue Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError
    # We rely on Package.get_by_project_and_name since it's the only way to work with multibuild packages.
    # It's possible for a package to not exist, so we simply rescue and do nothing. The package will be created later in the step.
  end

  def target_package_name(package_name: nil, short_commit_sha: false)
    package_name = package_name || step_instructions[:target_package] || step_instructions[:source_package]

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
