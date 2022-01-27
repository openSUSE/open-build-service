class Workflow::Step
  include ActiveModel::Model

  SHORT_COMMIT_SHA_LENGTH = 7

  validate :validate_step_instructions

  attr_accessor :scm_webhook, :step_instructions, :token

  def initialize(attributes = {})
    super
    @step_instructions = attributes[:step_instructions]&.deep_symbolize_keys || {}
  end

  def call(_options)
    raise AbstractMethodCalled
  end

  def target_project_name
    return target_project_base_name if scm_webhook.push_event? || scm_webhook.tag_push_event?

    return nil unless scm_webhook.pull_request_event?

    pr_subproject_name = if scm_webhook.payload[:scm] == 'github'
                           scm_webhook.payload[:target_repository_full_name]&.tr('/', ':')
                         else
                           scm_webhook.payload[:path_with_namespace]&.tr('/', ':')
                         end

    "#{target_project_base_name}:#{pr_subproject_name}:PR-#{scm_webhook.payload[:pr_number]}"
  end

  def target_package
    Package.get_by_project_and_name(target_project_name, target_package_name, follow_multibuild: true)
  rescue Project::Errors::UnknownObjectError, Package::Errors::UnknownObjectError
    # We rely on Package.get_by_project_and_name since it's the only way to work with multibuild packages.
    # It's possible for a package to not exist, so we simply rescue and do nothing. The package will be created later in the step.
  end

  def create_or_update_subscriptions(package, workflow_filters)
    ['Event::BuildFail', 'Event::BuildSuccess'].each do |build_event|
      subscription = EventSubscription.find_or_create_by!(eventtype: build_event,
                                                          receiver_role: 'reader', # We pass a valid value, but we don't need this.
                                                          user: @token.user,
                                                          channel: 'scm',
                                                          enabled: true,
                                                          token: @token,
                                                          package: package)
      subscription.update!(payload: scm_webhook.payload.merge({ workflow_filters: workflow_filters }))
    end
  end

  def target_package_name(short_commit_sha: false)
    package_name = step_instructions[:target_package] || source_package_name

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

  def validate_step_instructions
    self.class::REQUIRED_KEYS.each do |required_key|
      unless step_instructions.key?(required_key)
        errors.add(:base, "The '#{required_key}' key is missing")
        next
      end

      errors.add(:base, "The '#{required_key}' key must provide a value") if step_instructions[required_key].blank?
    end
  end

  def source_package_name
    step_instructions[:source_package]
  end

  def source_project_name
    step_instructions[:source_project]
  end

  def target_package_names
    [target_package_name(short_commit_sha: true)] + multibuild_flavors
  end

  private

  def multibuild_flavors
    target_package.multibuild_flavors.collect { |flavor| "#{target_package_name}:#{flavor}" }
  end

  def target_project_base_name
    raise AbstractMethodCalled
  end

  def remote_source?
    Project.find_remote_project(source_project_name).present?
  end

  def add_branch_request_file(package:)
    branch_request_file = case scm_webhook.payload[:scm]
                          when 'github'
                            branch_request_content_github
                          when 'gitlab'
                            branch_request_content_gitlab
                          end

    package.save_file({ file: branch_request_file, filename: '_branch_request' })
  end

  def branch_request_content_github
    {
      # TODO: change to scm_webhook.payload[:action]
      # when check_for_branch_request method in obs-service-tar_scm accepts other actions than 'opened'
      # https://github.com/openSUSE/obs-service-tar_scm/blob/2319f50e741e058ad599a6890ac5c710112d5e48/TarSCM/tasks.py#L145
      action: 'opened',
      pull_request: {
        head: {
          repo: { full_name: scm_webhook.payload[:source_repository_full_name] },
          sha: scm_webhook.payload[:commit_sha]
        }
      }
    }.to_json
  end

  def branch_request_content_gitlab
    { object_kind: scm_webhook.payload[:object_kind],
      project: { http_url: scm_webhook.payload[:http_url] },
      object_attributes: { source: { default_branch: scm_webhook.payload[:commit_sha] } } }.to_json
  end

  # TODO: Move to a query object.
  def workflow_repositories(target_project_name, filters)
    repositories = Project.get_by_name(target_project_name).repositories
    return repositories unless filters.key?(:repositories)

    return repositories.where(name: filters[:repositories][:only]) if filters[:repositories][:only]

    return repositories.where.not(name: filters[:repositories][:ignore]) if filters[:repositories][:ignore]

    repositories
  end

  # TODO: Move to a query object.
  def workflow_architectures(repository, filters)
    architectures = repository.architectures
    return architectures unless filters.key?(:architectures)

    return architectures.where(name: filters[:architectures][:only]) if filters[:architectures][:only]

    return architectures.where.not(name: filters[:architectures][:ignore]) if filters[:architectures][:ignore]

    architectures
  end

  def report_to_scm(workflow_filters)
    workflow_repositories(target_project_name, workflow_filters).each do |repository|
      # TODO: Fix n+1 queries
      workflow_architectures(repository, workflow_filters).each do |architecture|
        target_package_names.each do |target_package_name_or_flavor|
          SCMStatusReporter.new({ project: target_project_name, package: target_package_name_or_flavor, repository: repository.name, arch: architecture.name },
                                scm_webhook.payload, @token.scm_token).call
        end
      end
    end
  end

  # Only used in LinkPackageStep and BranchPackageStep.
  def validate_source_project_and_package_name
    errors.add(:base, "invalid source project '#{source_project_name}'") if step_instructions[:source_project] && !Project.valid_name?(source_project_name)
    errors.add(:base, "invalid source package '#{source_package_name}'") if step_instructions[:source_package] && !Package.valid_name?(source_package_name)
    errors.add(:base, "invalid target project '#{step_instructions[:target_project]}'") if step_instructions[:target_project] && !Project.valid_name?(step_instructions[:target_project])
  end
end
