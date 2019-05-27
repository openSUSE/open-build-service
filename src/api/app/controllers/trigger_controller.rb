class TriggerController < ApplicationController
  validate_action rebuild: { method: :post, response: :status }
  validate_action release: { method: :post, response: :status }
  validate_action runservice: { method: :post, response: :status }

  before_action :require_project_param, only: [:release]

  before_action :extract_auth_from_request, :validate_auth_token, :require_valid_token
  #
  # Authentication happens with tokens, so no login is required
  #
  skip_before_action :extract_user
  skip_before_action :require_login

  # to get access to the method release_package
  include MaintenanceHelper

  include Trigger::Errors

  def check_rebuild_permission!
    return if User.session.can_modify_project?(@prj)
    return if @pkg.project == @prj && policy(@pkg).update?

    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{@pkg} in project #{@prj}")
  end

  def rebuild
    check_rebuild_permission!
    Backend::Api::Sources::Package.rebuild(@prj.name, @pkg_name)
    render_ok
  end

  def release
    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{@pkg} in project #{@pkg.project}") unless policy(@pkg).update?

    matched_repo = false
    @pkg.project.repositories.includes(:release_targets).each do |repo|
      repo.release_targets.where(trigger: 'manual').each do |releasetarget|
        release_target_repository_project = releasetarget.target_repository.project
        unless policy(release_target_repository_project).update?
          raise NoPermissionForTarget.setup('no_permission',
                                            403, "no permission for target #{release_target_repository_project}")
        end
        target_package_name = @pkg.release_target_name

        # find md5sum and release source and binaries
        release_package(@pkg, releasetarget.target_repository, target_package_name, repo, nil, nil, nil, true)
        matched_repo = true
      end
    end

    raise NoPermissionForPackage.setup('not_found', 404, "no repository from #{@pkg.project} could get released") unless matched_repo

    render_ok
  end

  def runservice
    raise NoPermissionForPackage.setup('no_permission', 403, "no permission for package #{@pkg} in project #{@pkg.project}") unless policy(@pkg).update?

    # execute the service in backend
    path = @pkg.source_path
    params = { cmd: 'runservice', comment: 'runservice via trigger', user: User.session!.login }
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend(path)

    @pkg.sources_changed
  end

  private

  def require_project_param
    render_error(message: 'Token must define the release package', status: 403, errorcode: 'no_permission') if params[:project].present?
  end

  def extract_auth_from_request
    @token_extractor = ::TriggerControllerService::TokenExtractor.new(request).call
  end

  def validate_auth_token
    raise InvalidToken unless @token_extractor.valid?
  end

  def require_valid_token
    @token = @token_extractor.token

    raise TokenNotFound unless @token

    User.session = @token.user

    raise NoPermissionForInactive unless User.session.is_active?

    if @token.package
      @pkg = @token.package
      @pkg_name = @pkg.name
      @prj = @pkg.project
    else
      @prj = Project.get_by_name(params[:project])
      @pkg_name = params[:package] # for multibuild container
      if @token.class == Token::Rebuild
        opts = { use_source: false,
                 follow_project_links: true,
                 follow_multibuild: false }
      else
        opts = { use_source: true }
      end
      @pkg = Package.get_by_project_and_name(params[:project].to_s, params[:package].to_s, opts)
    end
  end
end
