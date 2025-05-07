class BsRequestPermissionCheck
  include BsRequest::Errors

  attr_accessor :opts, :req, :accept_user

  # check if the request can change state - or throw an APIError if not
  def initialize(request, options)
    self.req = request
    self.opts = options
    self.accept_user = if request.approver
                         User.find_by!(login: request.approver)
                       else
                         User.session!
                       end

    @write_permission_in_source = false
    @write_permission_in_target = false
  end

  def cmd_addreview_permissions(permissions_granted, relaxed_state_check = 0)
    raise ReviewChangeStateNoPermission, 'The request is not in state new or review' unless relaxed_state_check || req.state.in?(%i[review new])

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)
    end
    require_permissions_in_target_or_source unless permissions_granted
  end

  def cmd_setpriority_permissions
    raise SetPriorityNoPermission, 'The request is not in state new or review' unless req.state.in?(%i[review new])

    return if req.creator == User.session!.login

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)
    end
    return if @write_permission_in_target

    raise SetPriorityNoPermission, "You have not created the request and don't have write permission in target of request actions"
  end

  def cmd_setincident_permissions
    raise ReviewChangeStateNoPermission, 'The request is not in state new or review' unless req.state.in?(%i[review new])

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)

      raise TargetNotMaintenance, 'The target project is already an incident, changing is not possible via set_incident' if @target_project.maintenance_incident?
      raise TargetNotMaintenance, "The target project is not of type maintenance but #{@target_project.kind}" unless @target_project.kind == 'maintenance'

      tip = Project.get_by_name("#{action.target_project}:#{opts[:incident]}")
      raise ProjectLocked if tip && tip.locked?
    end

    require_permissions_in_target_or_source
  end

  def cmd_changereviewstate_permissions
    # Basic validations of given parameters
    by_user = User.find_by_login!(opts[:by_user]) if opts[:by_user]
    by_group = Group.find_by_title!(opts[:by_group]) if opts[:by_group]
    if opts[:by_project] && opts[:by_package]
      by_package = Package.get_by_project_and_name(opts[:by_project], opts[:by_package])
    elsif opts[:by_project]
      by_project = Project.get_by_name(opts[:by_project])
    end

    # Admin always ...
    return true if User.admin_session?

    raise ReviewChangeStateNoPermission, 'The request is neither in state review nor new' unless req.state.in?(%i[review new])
    raise ReviewNotSpecified, 'The review must specified via by_user, by_group or by_project(by_package) argument.' unless by_user || by_group || by_package || by_project
    raise ReviewChangeStateNoPermission, "review state change is not permitted for #{User.session!.login}" if by_user && User.session! != by_user
    raise ReviewChangeStateNoPermission, "review state change for group #{by_group.title} is not permitted for #{User.session!.login}" if by_group && !User.session!.in_group?(by_group)

    if by_package && !User.session!.can_modify?(by_package, true)
      raise ReviewChangeStateNoPermission, "review state change for package #{opts[:by_project]}/#{opts[:by_package]} " \
                                           "is not permitted for #{User.session!.login}"
    end

    return unless by_project && !User.session!.can_modify?(by_project, true)

    raise ReviewChangeStateNoPermission, "review state change for project #{opts[:by_project]} is not permitted for #{User.session!.login}"
  end

  def cmd_changestate_permissions
    # We do not support to revert changes from accepted requests (yet)
    raise PostRequestNoPermission, 'change state from an accepted state is not allowed.' if req.state == :accepted

    # need to check for accept permissions
    accept_check = opts[:newstate] == 'accepted'

    # enforce state to "review" if going to "new", when review tasks are open
    if opts[:newstate] == 'new' && req.reviews
      req.reviews.each do |r|
        opts[:newstate] = 'review' if r.state == :new
      end
    end
    # Do not accept to skip the review, except force argument is given
    if accept_check
      if req.state == :review
        raise PostRequestNoPermission, 'Request is in review state. You may use the force parameter to ignore this.' unless opts[:force]
      elsif req.state != :new
        raise PostRequestNoPermission, 'Request is not in new state. You may reopen it by setting it to new.'
      end
    end
    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    raise PostRequestNoPermission, "set state to #{opts[:newstate]} from a final state is not allowed." if req.state.in?(%i[accepted superseded revoked]) && opts[:newstate].in?(%w[accepted declined superseded revoked])

    raise PostRequestMissingParameter, "Supersed a request requires a 'superseded_by' parameter with the request id." if opts[:newstate] == 'superseded' && !opts[:superseded_by]

    target_project = req.bs_request_actions.first.target_project_object
    user_is_staging_manager = User.session!.groups_users.exists?(group: target_project.staging.managers_group) if target_project && target_project.staging

    if opts[:newstate] == 'deleted' && !User.admin_session?
      raise PostRequestNoPermission, 'Deletion of a request is only permitted for administrators. Please revoke the request instead.'
    end

    permission_granted =
      User.admin_session? ||

      # request creator can reopen, revoke or supersede a request which was declined
      (opts[:newstate].in?(%w[new review revoked superseded]) && req.creator == User.session!.login) ||

      # NOTE: request should be revoked if project is removed.
      # override_creator is needed if the logged in user is different than the creator of the request
      # at the time of removing the project.
      (opts[:newstate] == 'revoked' && req.creator == opts[:override_creator]) ||

      # people who declined a request shall also be able to reopen it

      # NOTE: Staging managers should be able to repoen a request to unstage a declined request.
      # The reason behind `user_is_staging_manager`, is that we need to manage reviews to send
      # the request to the staging backlog.
      (req.state == :declined && opts[:newstate].in?(%w[new review]) && (req.commenter == User.session!.login || user_is_staging_manager))

    # permission and validation check for each action inside
    req.bs_request_actions.each do |action|
      set_permissions_for_action(action, accept_check ? 'accepted' : opts[:newstate])

      check_newstate_action!(action)

      # TODO: Get the relevant project attribute, from the target project or target package. Retrieve the accepter and check if it's the same person than the creator. And fail if true
      target_package = Package.get_by_project_and_name(action.target_project, action.target_package) if Package.exists_by_project_and_name(action.target_project, action.target_package)
      target_project = Project.find_by_name(action.target_project) if action.target_project
      if accept_check
        cannot_accept_request = target_package&.find_attribute('OBS', 'CreatorCannotAcceptOwnRequests').present?
        cannot_accept_request ||= target_project&.find_attribute('OBS', 'CreatorCannotAcceptOwnRequests').present?
        raise BsRequest::Errors::CreatorCannotAcceptOwnRequests if cannot_accept_request && accept_user.login == req.creator
      end

      # abort immediatly if we want to write and can't
      next unless accept_check && !@write_permission_in_this_action

      msg = ''
      unless action.bs_request.new_record?
        msg = 'No permission to modify target of request ' \
              "#{action.bs_request.number} (type #{action.action_type}): project #{action.target_project}"
      end
      msg += ", package #{action.target_package}" if action.target_package
      raise PostRequestNoPermission, msg
    end

    extra_permissions_check_changestate unless permission_granted || opts[:cmd] == 'approve'
  end

  private

  def check_accepted_action(action)
    raise NotExistingTarget, "Unable to process project #{action.target_project}; it does not exist." unless @target_project

    check_action_target(action)

    # validate that specified sources do not have conflicts on accepting request
    if action.action_type.in?(%i[submit maintenance_incident])
      query = { expand: 1 }
      query[:rev] = action.source_rev if action.source_rev
      begin
        Backend::Api::Sources::Package.files(action.source_project, action.source_package, query)
      rescue Backend::Error
        raise ExpandError, "The source of package #{action.source_project}/#{action.source_package}#{action.source_rev ? " for revision #{action.source_rev}" : ''} is broken"
      end
    end

    # maintenance_release accept check
    if action.action_type == :maintenance_release
      # compare with current sources
      check_maintenance_release_accept(action)
    end

    # target must exist
    if action.action_type.in?(%i[delete add_role set_bugowner]) && action.target_package && !@target_package
      raise NotExistingTarget, "Unable to process package #{action.target_project}/#{action.target_package}; it does not exist."
    end

    check_delete_accept(action) if action.action_type == :delete

    return unless action.makeoriginolder && Package.exists_by_project_and_name(action.target_project, action.target_package)

    # the target project may link to another project where we need to check modification permissions
    originpkg = Package.get_by_project_and_name(action.target_project, action.target_package)
    return if accept_user.can_modify?(originpkg, true)

    raise PostRequestNoPermission, 'Package target can not get initialized using makeoriginolder.' \
                                   "No permission in project #{originpkg.project.name} for user #{accept_user.login} with request #{action.bs_request.number}"
  end

  def check_action_target(action)
    return unless action.action_type.in?(%i[submit change_devel maintenance_release maintenance_incident])

    raise PostRequestNoPermission, "Target package is missing in request #{action.bs_request.number} (type #{action.action_type})" if action.action_type == :change_devel && !action.target_package

    # full read access checks
    @target_project = Project.get_by_name(action.target_project)

    # require a local source package
    if @source_package
      @source_package.check_source_access!
    else
      case action.action_type
      when :change_devel
        err = "Local source package is missing for request #{action.bs_request.number} (type #{action.action_type})"
      when :set_bugowner, :add_role
        err = nil
      else
        action.source_access_check!
      end
      raise SourceMissing, err if err
    end
    # maintenance incident target permission checks
    return unless action.maintenance_incident?
    return if @target_project.kind.in?(%w[maintenance maintenance_incident])

    raise TargetNotMaintenance, "The target project is not of type maintenance or incident but #{@target_project.kind}"
  end

  def check_delete_accept(action)
    if @target_package
      return if opts.include?(:force) && opts[:force].in?([nil, '1'])

      @target_package.check_weak_dependencies!
    elsif action.target_repository
      r = Repository.find_by_project_and_name(@target_project.name, action.target_repository)
      raise RepositoryMissing, "The repository #{@target_project} / #{action.target_repository} does not exist" unless r
    else
      # remove entire project
      @target_project.check_weak_dependencies!
    end
  end

  def check_maintenance_release_accept(action)
    if action.source_rev
      # FIXME2.4 we have a directory model
      c = Backend::Api::Sources::Package.files(action.source_project, action.source_package, expand: 1)
      data = REXML::Document.new(c)
      unless action.source_rev == data.elements['directory'].attributes['srcmd5']
        raise SourceChanged, "The current source revision in #{action.source_project}/#{action.source_package} " \
                             "is not on revision #{action.source_rev} anymore."
      end
    end

    # write access check in release targets
    @source_project.repositories.each do |repo|
      repo.release_targets.each do |releasetarget|
        next unless releasetarget.trigger == 'maintenance'
        raise ReleaseTargetNoPermission, "Release target project #{releasetarget.target_repository.project.name} is not writable by you" unless User.session!.can_modify?(releasetarget.target_repository.project)
      end
    end

    # Is the source_project under embargo still?
    return if action.embargo_date.blank?
    return if opts[:force]

    raise BsRequest::Errors::UnderEmbargo, "The project #{action.source_project} is under embargo until #{action.embargo_date}" if action.embargo_date > Time.now.utc
  end

  # check if the action can change state - or throw an APIError if not
  def check_newstate_action!(action)
    # relaxed checks for final exit states
    return if opts[:newstate].in?(%w[declined revoked superseded])

    if opts[:newstate] == 'accepted' || opts[:cmd] == 'approve'
      check_accepted_action(action)
    else # only check the target is sane
      check_action_target(action)
    end
  end

  def extra_permissions_check_changestate
    err =
      case opts[:newstate]
      when 'superseded'
        # Is the user involved in any project or package ?
        "You have no role in request #{req.number}" unless @write_permission_in_target || @write_permission_in_source
      when 'accepted'
        nil
      # requires write permissions in all targets, this is already handled in each action check
      when 'revoked'
        # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
        "No permission to revoke request #{req.number}" unless @write_permission_in_source
      when 'new'
        if (req.state == :revoked && !@write_permission_in_source) ||
           (req.state == :declined && !@write_permission_in_target)
          "No permission to reopen request #{req.number}"
        end
      when 'declined'
        unless @write_permission_in_target
          # at least on one target the permission must be granted on decline
          "No permission to decline request #{req.number}"
        end
      else
        "No permission to change request #{req.number} state"
      end
    raise PostRequestNoPermission, err if err
  end

  # Is the user involved in any project or package ?
  def require_permissions_in_target_or_source
    raise AddReviewNotPermitted, "You have no role in request #{req.number}" unless @write_permission_in_target || @write_permission_in_source

    true
  end

  def set_permissions_for_action(action, new_state = nil)
    # general write permission check on the target on accept
    @write_permission_in_this_action = false

    # all action types need a target project in any case for accept
    @target_project = Project.find_by_name(action.target_project)
    @target_package = @source_package = nil

    @target_package = @target_project.packages.find_by_name(action.target_package) if action.target_package && @target_project

    @source_project = nil
    @source_package = nil
    if action.source_project
      @source_project = Project.find_by_name(action.source_project)
      @source_package = Package.find_by_project_and_name(action.source_project, action.source_package) if action.source_package && @source_project
    end

    if action.action_type == :maintenance_incident
      # this action type is always branching using extended names
      target_package_name = Package.extended_name(action.source_project, action.source_package)
      @target_package = @target_project.packages.find_by_name(target_package_name) if @target_project
    end

    # general source write permission check (for revoke)
    if (@source_package && User.session!.can_modify?(@source_package, true)) ||
       (!@source_package && @source_project && User.session!.can_modify?(@source_project, true))
      @write_permission_in_source = true
    end

    # general write permission check on the target on accept
    @write_permission_in_this_action = false
    # meta data change shall also be allowed after freezing a project using force:
    ignore_lock = (new_state == 'declined') ||
                  (opts[:force] && action.action_type == :set_bugowner)
    if @target_package
      if accept_user.can_modify?(@target_package, ignore_lock)
        @write_permission_in_target = true
        @write_permission_in_this_action = true
      end
    else
      @write_permission_in_target = true if @target_project && PackagePolicy.new(accept_user, Package.new(project: @target_project), ignore_lock: true).create?
      @write_permission_in_this_action = true if @target_project && PackagePolicy.new(accept_user, Package.new(project: @target_project), ignore_lock: ignore_lock).create?
    end
  end
end
