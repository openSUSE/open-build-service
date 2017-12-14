class BsRequestPermissionCheck
  class AddReviewNotPermitted < APIException
    setup 403
  end

  class NotExistingTarget < APIException;
    setup 404
  end

  class SourceChanged < APIException;
  end

  class ReleaseTargetNoPermission < APIException
    setup 403
  end

  class ProjectLocked < APIException
    setup 403, 'The target project is locked'
  end

  class TargetNotMaintenance < APIException
    setup 404
  end

  class SourceMissing < APIException
    setup 'unknown_package', 404
  end

  class SetPriorityNoPermission < APIException
    setup 403
  end

  class ReviewChangeStateNoPermission < APIException
    setup 403
  end

  class ReviewNotSpecified < APIException;
  end

  def check_accepted_action(action)
    unless @target_project
      raise NotExistingTarget, "Unable to process project #{action.target_project}; it does not exist."
    end

    check_action_target(action)

    # validate that specified sources do not have conflicts on accepting request
    if action.action_type.in?([:submit, :maintenance_incident])
      query = { expand: 1 }
      query[:rev] = action.source_rev if action.source_rev
      begin
        Backend::Api::Sources::Package.files(action.source_project, action.source_package, query)
      rescue ActiveXML::Transport::Error
        # rubocop:disable Metrics/LineLength
        raise ExpandError, "The source of package #{action.source_project}/#{action.source_package}#{action.source_rev ? " for revision #{action.source_rev}" : ''} is broken"
        # rubocop:enable Metrics/LineLength
      end
    end

    # maintenance_release accept check
    if action.action_type == :maintenance_release
      # compare with current sources
      check_maintenance_release_accept(action)
    end

    if action.action_type.in?([:delete, :add_role, :set_bugowner])
      # target must exist
      if action.target_package
        unless @target_package
          raise NotExistingTarget, "Unable to process package #{action.target_project}/#{action.target_package}; it does not exist."
        end
      end
    end

    if action.action_type == :delete
      check_delete_accept(action)
    end

    return unless action.makeoriginolder && Package.exists_by_project_and_name(action.target_project, action.target_package)

    # the target project may link to another project where we need to check modification permissions
    originpkg = Package.get_by_project_and_name action.target_project, action.target_package
    return if User.current.can_modify_package?(originpkg, true)

    raise PostRequestNoPermission, "Package target can not get initialized using makeoriginolder." +
                                   "No permission in project #{originpkg.project.name}"
  end

  def check_delete_accept(action)
    if @target_package
      @target_package.check_weak_dependencies!
    elsif action.target_repository
      r = Repository.find_by_project_and_name(@target_project.name, action.target_repository)
      unless r
        raise RepositoryMissing, "The repository #{@target_project} / #{action.target_repository} does not exist"
      end
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
        raise SourceChanged, "The current source revision in #{action.source_project}/#{action.source_package}" +
                             "are not on revision #{action.source_rev} anymore."
      end
    end

    # write access check in release targets
    @source_project.repositories.each do |repo|
      repo.release_targets.each do |releasetarget|
        next unless releasetarget.trigger == 'maintenance'
        unless User.current.can_modify_project? releasetarget.target_repository.project
          raise ReleaseTargetNoPermission, "Release target project #{releasetarget.target_repository.project.name} is not writable by you"
        end
      end
    end
  end

  # check if the action can change state - or throw an APIException if not
  def check_newstate_action!(action, opts)
    # relaxed checks for final exit states
    return if opts[:newstate].in?(["declined", "revoked", "superseded"])

    if opts[:newstate] == 'accepted'
      check_accepted_action(action)
    else # only check the target is sane
      check_action_target(action)
    end
  end

  def check_action_target(action)
    return unless action.action_type.in?([:submit, :change_devel, :maintenance_release, :maintenance_incident])

    if action.action_type == :change_devel && !action.target_package
      raise PostRequestNoPermission, "Target package is missing in request #{action.bs_request.number} (type #{action.action_type})"
    end

    # full read access checks
    @target_project = Project.get_by_name(action.target_project)

    # require a local source package
    if @source_package
      @source_package.check_source_access!
    else
      err = nil
      case action.action_type
      when :change_devel
        err = "Local source package is missing for request #{action.bs_request.number} (type #{action.action_type})"
      when :set_bugowner
      when :add_role
      else
        action.source_access_check!
      end
      raise SourceMissing, err if err
    end
    # maintenance incident target permission checks
    return unless action.is_maintenance_incident?
    return if @target_project.kind.in?(["maintenance", "maintenance_incident"])

    raise TargetNotMaintenance, "The target project is not of type maintenance or incident but #{@target_project.kind}"
  end

  def set_permissions_for_action(action, new_state = nil)
    # general write permission check on the target on accept
    @write_permission_in_this_action = false

    # all action types need a target project in any case for accept
    @target_project = Project.find_by_name(action.target_project)
    @target_package = @source_package = nil

    if action.target_package && @target_project
      @target_package = @target_project.packages.find_by_name(action.target_package)
    end

    @source_project = nil
    @source_package = nil
    if action.source_project
      @source_project = Project.find_by_name(action.source_project)
      if action.source_package && @source_project
        @source_package = Package.find_by_project_and_name action.source_project, action.source_package
      end
    end

    if action.action_type == :maintenance_incident
      # this action type is always branching using extended names
      target_package_name = Package.extended_name(action.source_project, action.source_package)
      @target_package = @target_project.packages.find_by_name(target_package_name) if @target_project
    end

    # general source write permission check (for revoke)
    if (@source_package && User.current.can_modify_package?(@source_package, true)) ||
       (!@source_package && @source_project && User.current.can_modify_project?(@source_project, true))
      @write_permission_in_source = true
    end

    # general write permission check on the target on accept
    @write_permission_in_this_action = false
    # meta data change shall also be allowed after freezing a project using force:
    ignore_lock = (new_state == "declined") || \
                  (opts[:force] && action.action_type == :set_bugowner)
    if @target_package
      if User.current.can_modify_package?(@target_package, ignore_lock)
        @write_permission_in_target = true
        @write_permission_in_this_action = true
      end
    else
      if @target_project && User.current.can_create_package_in?(@target_project, true)
        @write_permission_in_target = true
      end
      if @target_project && User.current.can_create_package_in?(@target_project, ignore_lock)
        @write_permission_in_this_action = true
      end
    end
  end

  def cmd_addreview_permissions(permissions_granted)
    unless req.state.in?([:review, :new])
      raise ReviewChangeStateNoPermission, 'The request is not in state new or review'
    end

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)
    end
    require_permissions_in_target_or_source unless permissions_granted
  end

  def cmd_setpriority_permissions
    unless req.state.in?([:review, :new])
      raise SetPriorityNoPermission, 'The request is not in state new or review'
    end

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)
    end
    return if @write_permission_in_target

    raise SetPriorityNoPermission, 'No write permission in target of request actions'
  end

  def cmd_setincident_permissions
    unless req.state.in?([:review, :new])
      raise ReviewChangeStateNoPermission, 'The request is not in state new or review'
    end

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)

      if @target_project.is_maintenance_incident?
        raise TargetNotMaintenance, 'The target project is already an incident, changing is not possible via set_incident'
      end
      unless @target_project.kind == 'maintenance'
        raise TargetNotMaintenance, "The target project is not of type maintenance but #{@target_project.kind}"
      end
      tip = Project.get_by_name(action.target_project + ':' + opts[:incident])
      if tip && tip.is_locked?
        raise ProjectLocked
      end
    end

    require_permissions_in_target_or_source
  end

  def cmd_changereviewstate_permissions(opts)
    # Basic validations of given parameters
    by_user = User.find_by_login!(opts[:by_user]) if opts[:by_user]
    by_group = Group.find_by_title!(opts[:by_group]) if opts[:by_group]
    if opts[:by_project] && opts[:by_package]
      by_package = Package.get_by_project_and_name(opts[:by_project], opts[:by_package])
    elsif opts[:by_project]
      by_project = Project.get_by_name(opts[:by_project])
    end

    # Admin always ...
    return true if User.current.is_admin?

    unless req.state.in?([:review, :new])
      raise ReviewChangeStateNoPermission, 'The request is neither in state review nor new'
    end
    unless by_user || by_group || by_package || by_project
      raise ReviewNotSpecified, 'The review must specified via by_user, by_group or by_project(by_package) argument.'
    end
    if by_user && !(User.current == by_user)
      raise ReviewChangeStateNoPermission, "review state change is not permitted for #{User.current.login}"
    end
    if by_group && !User.current.is_in_group?(by_group)
      raise ReviewChangeStateNoPermission, "review state change for group #{by_group.title} is not permitted for #{User.current.login}"
    end
    if by_package && !User.current.can_modify_package?(by_package, true)
      raise ReviewChangeStateNoPermission, "review state change for package #{opts[:by_project]}/#{opts[:by_package]} " +
                                           "is not permitted for #{User.current.login}"
    end

    return unless by_project && !User.current.can_modify_project?(by_project, true)
    raise ReviewChangeStateNoPermission, "review state change for project #{opts[:by_project]} is not permitted for #{User.current.login}"
  end

  def cmd_changestate_permissions(opts)
    # We do not support to revert changes from accepted requests (yet)
    if req.state == :accepted
      raise PostRequestNoPermission, 'change state from an accepted state is not allowed.'
    end

    # enforce state to "review" if going to "new", when review tasks are open
    if opts[:newstate] == 'new' && req.reviews
      req.reviews.each do |r|
        opts[:newstate] = 'review' if r.state == :new
      end
    end
    # Do not accept to skip the review, except force argument is given
    if opts[:newstate] == 'accepted'
      if req.state == :review
        unless opts[:force]
          raise PostRequestNoPermission, 'Request is in review state. You may use the force parameter to ignore this.'
        end
      elsif req.state != :new
        raise PostRequestNoPermission, 'Request is not in new state. You may reopen it by setting it to new.'
      end
    end
    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if req.state.in?([:accepted, :superseded, :revoked])
      if opts[:newstate].in?(["accepted", "declined", "superseded", "revoked"])
        raise PostRequestNoPermission, "set state to #{opts[:newstate]} from a final state is not allowed."
      end
    end

    if opts[:newstate] == 'superseded' && !opts[:superseded_by]
      raise PostRequestMissingParamater, "Supersed a request requires a 'superseded_by' parameter with the request id."
    end

    permission_granted = false
    if User.current.is_admin?
      permission_granted = true
    elsif opts[:newstate] == 'deleted'
      raise PostRequestNoPermission, 'Deletion of a request is only permitted for administrators. Please revoke the request instead.'
    end

    if opts[:newstate].in?(["new", "review", "revoked", "superseded"]) && req.creator == User.current.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state == :declined && opts[:newstate].in?(["new", "review"]) && req.commenter == User.current.login
      # people who declined a request shall also be able to reopen it
      permission_granted = true
    end

    # permission and validation check for each action inside
    req.bs_request_actions.each do |action|
      set_permissions_for_action(action, opts[:newstate])

      check_newstate_action! action, opts

      # abort immediatly if we want to write and can't
      if opts[:newstate] == "accepted" && !@write_permission_in_this_action
        msg = ''
        msg = "No permission to modify target of request " +
              "#{action.bs_request.number} (type #{action.action_type}): project #{action.target_project}" unless action.bs_request.new_record?
        msg += ", package #{action.target_package}" if action.target_package
        raise PostRequestNoPermission, msg
      end
    end

    extra_permissions_check_changestate unless permission_granted
  end

  attr_accessor :opts, :req

  # check if the request can change state - or throw an APIException if not
  def initialize(_req, _opts)
    self.req = _req
    self.opts = _opts

    @write_permission_in_source = false
    @write_permission_in_target = false
  end

  # Is the user involved in any project or package ?
  def require_permissions_in_target_or_source
    unless @write_permission_in_target || @write_permission_in_source
      raise AddReviewNotPermitted, "You have no role in request #{req.number}"
    end
    true
  end

  def extra_permissions_check_changestate
    err =
      case opts[:newstate]
      when 'superseded'
        # Is the user involved in any project or package ?
        unless @write_permission_in_target || @write_permission_in_source
          "You have no role in request #{req.number}"
        end
      when 'accepted'
      # requires write permissions in all targets, this is already handled in each action check
      when 'revoked'
        # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
        unless @write_permission_in_source
          "No permission to revoke request #{req.number}"
        end
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
end
