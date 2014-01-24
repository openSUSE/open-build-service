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

  # check if the action can change state - or throw an APIException if not
  def check_newstate_action!(action, opts)

    if not @target_project and opts[:newstate] == 'accepted'
      raise NotExistingTarget.new "Unable to process project #{action.target_project}; it does not exist."
    end

    if [:submit, :change_devel, :maintenance_release, :maintenance_incident].include? action.action_type
      # relaxed checks for final exit states
      unless %w(declined revoked superseded).include? opts[:newstate]
        # full read access checks
        @source_project = Project.get_by_name(action.source_project)
        @target_project = Project.get_by_name(action.target_project)
        if action.action_type == :change_devel and !action.target_package
          raise PostRequestNoPermission.new "Target package is missing in request #{action.bs_request.id} (type #{action.action_type})"
        end
        if @source_package # retry for access check
          @source_package = Package.get_by_project_and_name action.source_project, action.source_package
        end
        # require a local source package
        if [:change_devel].include? action.action_type
          unless @source_package
            raise SourceMissing.new "Local source package is missing for request #{action.bs_request.id} (type #{action.action_type})"
          end
        end
        # accept also a remote source package
        if !@source_package and [:submit].include? action.action_type
          unless Package.exists_by_project_and_name(@source_project.name, action.source_package,
                                                    follow_project_links: true, allow_remote_packages: true)
            raise SourceMissing.new "Source package is missing for request #{action.bs_request.id} (type #{action.action_type})"
          end
        end
        # maintenance incident target permission checks
        if action.is_maintenance_incident?
          unless %w(maintenance maintenance_incident).include? @target_project.project_type.to_s
            raise TargetNotMaintenance.new "The target project is not of type maintenance or incident but #{@target_project.project_type}"
          end
        end
        # validate that specified sources do not have conflicts on accepting request
        if [:submit, :maintenance_incident].include? action.action_type and opts[:cmd] == 'changestate' and opts[:newstate] == 'accepted'
          query = { expand: 1 }
          query[:rev] = action.source_rev if action.source_rev
          url = Package.source_path(action.source_project, action.source_package, nil, query)
          begin
            ActiveXML.backend.direct_http(url)
          rescue ActiveXML::Transport::Error
            raise ExpandError.new "The source of package #{action.source_project}/#{action.source_package}#{action.source_rev ? " for revision #{action.source_rev}" : ''} is broken"
          end
        end
        # maintenance_release accept check
        if [:maintenance_release].include? action.action_type and opts[:newstate] == 'accepted'
          # compare with current sources
          if action.source_rev
            # FIXME2.4 we have a directory model
            url = Package.source_path(action.source_project, action.source_package, nil, expand: 1)
            c = ActiveXML.backend.direct_http(url)
            data = REXML::Document.new(c)
            unless action.source_rev == data.elements['directory'].attributes['srcmd5']
              raise SourceChanged.new "The current source revision in #{action.source_project}/#{action.source_package} are not on revision #{action.source_rev} anymore."
            end
          end

          # write access check in release targets
          @source_project.repositories.each do |repo|
            repo.release_targets.each do |releasetarget|
              unless User.current.can_modify_project? releasetarget.target_repository.project
                raise ReleaseTargetNoPermission.new "Release target project #{releasetarget.target_repository.project.name} is not writable by you"
              end
            end
          end
        end
      end
    end
    if [:delete, :add_role, :set_bugowner].include? action.action_type
      return unless opts[:newstate] == 'accepted'

      # target must exist
      if action.target_package
        unless @target_package
          raise NotExistingTarget.new "Unable to process package #{action.target_project}/#{action.target_package}; it does not exist."
        end
        if action.action_type == :delete
          @target_package.can_be_deleted?
        end
      else
        if action.action_type == :delete
          if action.target_repository
            r=Repository.find_by_project_and_repo_name(@target_project.name, action.target_repository)
            unless r
              raise RepositoryMissing.new "The repository #{@target_project} / #{action.target_repository} does not exist"
            end
          else
            # remove entire project
            @target_project.can_be_deleted?
          end
        end
      end
    end
  end

  def set_permissions_for_action(action)

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

    # general source write permission check (for revoke)
    if (@source_package and User.current.can_modify_package?(@source_package, true)) or
        (not @source_package and @source_project and User.current.can_modify_project?(@source_project, true))
      @write_permission_in_source = true
    end

    # general write permission check on the target on accept
    @write_permission_in_this_action = false
    # meta data change shall also be allowed after freezing a project using force:
    ignoreLock = opts[:force] and [:set_bugowner].include? action.action_type
    if @target_package
      if User.current.can_modify_package?(@target_package, ignoreLock)
        @write_permission_in_target = true
        @write_permission_in_this_action = true
      end
    else
      if @target_project and User.current.can_create_package_in?(@target_project, true)
        @write_permission_in_target = true
      end
      if @target_project and User.current.can_create_package_in?(@target_project, ignoreLock)
        @write_permission_in_this_action = true
      end
    end
  end

  def cmd_addreview_permissions(permissions_granted)
    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)
    end
    require_permissions_in_target_or_source unless permissions_granted
  end

  def cmd_setincident_permissions(permissions_granted)
    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)

      if @target_project.is_maintenance_incident?
        raise TargetNotMaintenance.new 'The target project is already an incident, changing is not possible via set_incident'
      end
      unless @target_project.project_type == 'maintenance'
        raise TargetNotMaintenance.new "The target project is not of type maintenance but #{@target_project.project_type}"
      end
      tip = Project.get_by_name(action.target_project + ':' + opts[:incident])
      if tip && tip.is_locked?
        raise ProjectLocked.new
      end
    end

    require_permissions_in_target_or_source unless permissions_granted
  end

  def cmd_changestate_permissions(permissions_granted)
    # permission and validation check for each action inside

    req.bs_request_actions.each do |action|
      set_permissions_for_action(action)

      check_newstate_action! action, opts

      # abort immediatly if we want to write and can't
      if %w(accepted).include? opts[:newstate] and not @write_permission_in_this_action
        msg = ''
        msg = "No permission to modify target of request #{action.bs_request.id} (type #{action.action_type}): project #{action.target_project}" unless action.bs_request.new_record?
        msg += ", package #{action.target_package}" if action.target_package
        raise PostRequestNoPermission.new msg
      end
    end

    extra_permissions_check_changestate unless permissions_granted
  end

  def cmd_permissions(cmd, permissions_granted)
    if cmd == 'changestate'
      cmd_changestate_permissions(permissions_granted)
    elsif cmd == 'addreview'
      cmd_addreview_permissions(permissions_granted)
    elsif cmd == 'setincident'
      cmd_setincident_permissions(permissions_granted)
    else
      Rails.logger.debug "no extra permissions check for cmd #{cmd}"
    end
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
    unless @write_permission_in_target or @write_permission_in_source
      raise AddReviewNotPermitted.new "You have no role in request #{req.id}"
    end
    true
  end

  def extra_permissions_check_changestate
    err = case opts[:newstate]
    when 'superseded'
      # Is the user involved in any project or package ?
      unless @write_permission_in_target or @write_permission_in_source
        "You have no role in request #{req.id}"
      end
    when 'accepted'
      # requires write permissions in all targets, this is already handled in each action check
    when 'revoked'
      # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
      unless @write_permission_in_source
        "No permission to revoke request #{req.id}"
      end
    when 'new'
      if (req.state == :revoked && !@write_permission_in_source) ||
         (req.state == :declined && !@write_permission_in_target)
          "No permission to reopen request #{req.id}"
      end
    when 'declined'
      unless @write_permission_in_target
        # at least on one target the permission must be granted on decline
        "No permission to decline request #{req.id}"
      end
    else
      "No permission to change request #{req.id} state"
    end
    raise PostRequestNoPermission.new err  if err
  end
end
