class Workflow::Step::BranchPackageStep < Workflow::Step
  include ScmSyncEnabledStep
  include TargetProjectLifeCycleSupport
  include WorkflowStepTargetObjects

  REQUIRED_KEYS = %i[source_project source_package target_project].freeze
  BRANCH_REQUEST_COMMIT_MESSAGE = 'Updated _branch_request file via SCM/CI Workflow run'.freeze

  def call
    return unless valid?

    authorize_target_project

    if scm_webhook.closed_merged_pull_request?
      destroy_target_project
    elsif scm_webhook.reopened_pull_request?
      restore_target_project
    elsif scm_webhook.new_commit_event?
      authorize_source_package
      create_branched_package
      unless scm_synced?
        target_package.save_file({ file: branch_request_content,
                                   filename: '_branch_request',
                                   comment: BRANCH_REQUEST_COMMIT_MESSAGE })
      end
      Workflows::ScmEventSubscriptionCreator.new(token, workflow_run, scm_webhook, target_package).call

      target_package
    end
  end

  private

  def skip_repositories?
    return false if step_instructions[:add_repositories].blank?

    step_instructions[:add_repositories] != 'enabled'
  end

  def authorize_source_package
    # if we branch from remote there is no need to check access. Either the package exists or not...
    return if Project.find_remote_project(step_instructions[:source_project]).present?

    # we don't have any package records on the frontend level for scmsynced projects, therefore
    # we can only check on the project level for sourceaccess permission
    if scm_synced_project?
      Pundit.authorize(@token.executor, Project.get_by_name(step_instructions[:source_project]), :source_access?)
      return
    end

    options = { use_source: false, follow_multibuild: true }

    begin
      src_package = Package.get_by_project_and_name(step_instructions[:source_project], step_instructions[:source_package], options)
    rescue Package::UnknownObjectError
      raise BranchPackage::Errors::CanNotBranchPackageNotFound, "Package #{step_instructions[:source_project]}/#{step_instructions[:source_package]} not found, it could not be branched."
    end

    Pundit.authorize(@token.executor, src_package, :create_branch?)
  end

  def create_branched_package
    return if target_package.present?

    # BranchPackage.branch below will skip "copying" repositories from the source project if the target project already exists...
    create_target_project if skip_repositories?

    branch_options = { project: step_instructions[:source_project], package: step_instructions[:source_package],
                       target_project: target_project_name, target_package: target_package_name,
                       scmsync: parse_scmsync_for_target_package }

    begin
      # Service running on package avoids branching it: wait until services finish
      Backend::Api::Sources::Package.wait_service(step_instructions[:source_project], step_instructions[:source_package])

      BranchPackage.new(branch_options).branch
    rescue BranchPackage::InvalidArgument, InvalidProjectNameError, ArgumentError => e
      raise BranchPackage::Errors::CanNotBranchPackage, "Package #{step_instructions[:source_project]}/#{step_instructions[:source_package]} could not be branched: #{e.message}"
    rescue Project::WritePermissionError, CreateProjectNoPermission => e
      raise BranchPackage::Errors::CanNotBranchPackageNoPermission,
            "Package #{step_instructions[:source_project]}/#{step_instructions[:source_package]} could not be branched due to missing permissions: #{e.message}"
    end

    Event::BranchCommand.create(project: step_instructions[:source_project], package: step_instructions[:source_package],
                                targetproject: target_project_name,
                                targetpackage: target_package_name,
                                user: @token.executor.login)
  end

  def branch_request_content
    case scm_webhook.payload[:scm]
    when 'github'
      branch_request_content_github
    when 'gitlab'
      branch_request_content_gitlab
    when 'gitea'
      branch_request_content_gitea
    end
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

  def branch_request_content_gitea
    { object_kind: 'merge_request',
      project: { http_url: scm_webhook.payload[:http_url] },
      object_attributes: { source: { default_branch: scm_webhook.payload[:commit_sha] } } }.to_json
  end
end
