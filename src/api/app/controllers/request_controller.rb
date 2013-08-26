require 'base64'

include MaintenanceHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  #TODO: allow PUT for non-admins
  before_filter :require_admin, :only => [:update, :destroy]

  # GET /request
  def index
    if params[:view] == "collection"

      # Do not allow a full collection to avoid server load
      if params[:project].blank? and params[:user].blank? and params[:states].blank? and params[:types].blank? and params[:reviewstates].blank? and params[:ids].blank?
        render_error :status => 404, :errorcode => 'require_filter',
                     :message => "This call requires at least one filter, either by user, project or package or states or types or reviewstates"
        return
      end

      # convert comma seperated values into arrays
      roles = params[:roles].split(',') if params[:roles]
      types = params[:types].split(',') if params[:types]
      states = params[:states].split(',') if params[:states]
      review_states = params[:reviewstates].split(',') if params[:reviewstates]
      ids = params[:ids].split(',').map { |i| i.to_i } if params[:ids]

      params.merge!({states: states, types: types, review_states: review_states, roles: roles, ids: ids})
      rel = BsRequestCollection.new(params).relation
      rel = rel.includes([:reviews, :bs_request_histories])
      rel = rel.includes({bs_request_actions: :bs_request_action_accept_info})
      rel = rel.order('bs_requests.id').references(:bs_requests)

      xml = ActiveXML::Node.new "<collection/>"
      matches=0
      rel.each do |r|
        matches = matches+1
        xml.add_node(r.render_xml)
      end
      xml.set_attribute("matches", matches.to_s)
      render :text => xml.dump_xml, :content_type => "text/xml"
    else
      # directory list of all requests. not very useful but for backward compatibility...
      # OBS3: make this more useful
      builder = Nokogiri::XML::Builder.new
      builder.directory do
        BsRequest.order(:id).pluck(:id).each do |r|
          builder.entry name: r
        end
      end
      render :text => builder.to_xml, :content_type => "text/xml"
    end
  end

  validate_action :show => {:method => :get, :response => :request}

  # GET /request/:id
  def show
    required_parameters :id

    req = BsRequest.find(params[:id])
    send_data(req.render_xml, :type => "text/xml")
  end

  # POST /request/:id? :cmd :newstate
  alias_method :command, :dispatch_command

  # PUT /request/:id
  def update
    BsRequest.transaction do
      oldrequest = BsRequest.find params[:id]
      oldrequest.destroy

      req = BsRequest.new_from_xml(request.body.read)
      req.id = params[:id]
      req.save!

      notify = oldrequest.notify_parameters
      Suse::Backend.send_notification("SRCSRV_REQUEST_CHANGE", notify)

      send_data(req.render_xml, :type => "text/xml")
    end
  end

  # DELETE /request/:id
  def destroy
    request = BsRequest.find(params[:id])
    notify = request.notify_parameters
    request.destroy # throws us out of here if failing
    Suse::Backend.send_notification("SRCSRV_REQUEST_DELETE", notify)
    render_ok
  end

  private

  def create_expand_package(action, packages)

    newactions = Array.new
    incident_suffix = ""
    if action.action_type == :maintenance_release
      # The maintenance ID is always the sub project name of the maintenance project
      incident_suffix = "." + action.source_project.gsub(/.*:/, "")
    end

    found_patchinfo = nil
    newPackages = Array.new
    newTargets = Array.new
    logger.debug "expand package #{packages.inspect}"

    packages.each do |pkg|
      # find target via linkinfo or submit to all.
      # FIXME: this is currently handling local project links for packages with multiple spec files. 
      #        This can be removed when we handle this as shadow packages in the backend.
      tprj = pkg.project.name
      tpkg = ltpkg = pkg.name
      rev = action.source_rev
      data = nil
      missing_ok_link=false
      suffix = ""
      while tprj == pkg.project.name
        # FIXME2.4 we have a Directory model!
        data = REXML::Document.new(backend_get("/source/#{URI.escape(tprj)}/#{URI.escape(ltpkg)}"))
        e = data.elements["directory/linkinfo"]
        if e
          suffix = ltpkg.gsub(/^#{e.attributes["package"]}/, '')
          ltpkg = e.attributes["package"]
          tprj = e.attributes["project"]
          missing_ok_link=true if e.attributes["missingok"]
        else
          tprj = nil
        end
      end
      tpkg = tpkg.gsub(/#{suffix}$/, '') # strip distro specific extension

      # maintenance incidents need a releasetarget
      releaseproject = action.get_releaseproject(pkg, tprj)

      # do not allow release requests without binaries
      if action.action_type == :maintenance_release and data and params["ignore_build_state"].nil?
        entries = data.get_elements("directory/entry")
        entries.each do |entry|
          next unless entry.attributes["name"] == "_patchinfo"
          # check for build state and binaries
          state = REXML::Document.new(backend_get("/build/#{URI.escape(pkg.project.name)}/_result"))
          repos = state.get_elements("/resultlist/result[@project='#{pkg.project.name}'')]")
          unless repos
            render_error :status => 400, :errorcode => 'build_not_finished',
                         :message => "The project'#{pkg.project.name}' has no building repositories"
            return
          end
          repos.each do |repo|
            unless ["finished", "publishing", "published", "unpublished"].include? repo.attributes['state']
              render_error :status => 400, :errorcode => 'build_not_finished',
                           :message => "The repository '#{pkg.project.name}' / '#{repo.attributes['repository']}' / #{repo.attributes['arch']}"
              return
            end
          end
          pkg.project.repositories.each do |repo|
            firstarch=repo.architectures.first if repo
            if firstarch
              # skip excluded patchinfos
              status = state.get_elements("/resultlist/result[@repository='#{repo.name}' and @arch='#{firstarch.name}']").first
              unless status and s=status.get_elements("status[@package='#{pkg.name}']").first and s.attributes['code'] == "excluded"
                binaries = REXML::Document.new(backend_get("/build/#{URI.escape(pkg.project.name)}/#{URI.escape(repo.name)}/#{URI.escape(firstarch.name)}/#{URI.escape(pkg.name)}"))
                l = binaries.get_elements("binarylist/binary")
                if l and l.count > 0
                  found_patchinfo = 1
                else
                  render_error :status => 400, :errorcode => 'build_not_finished',
                               :message => "patchinfo #{pkg.name} is not yet build for repository '#{repo.name}'"
                  return
                end
              end
            end
          end
        end
      end
      # Will this be a new package ?
      unless missing_ok_link
        unless e and Package.exists_by_project_and_name(tprj, tpkg, follow_project_links: true, allow_remote_packages: false)
          if action.action_type == :maintenance_release
            newPackages << pkg
            pkg.project.repositories.includes(:release_targets).each do |repo|
              repo.release_targets.each do |rt|
                newTargets << rt.target_repository.project.name
              end
            end
            next
          elsif action.action_type != :maintenance_incident
            render_error :status => 400, :errorcode => 'unknown_target_package',
                         :message => "target package does not exist"
            return
          end
        end
      end
      # is this package source going to a project which is specified as release target ?
      if action.action_type == :maintenance_release
        found = nil
        pkg.project.repositories.includes(:release_targets).each do |repo|
          repo.release_targets.each do |rt|
            if rt.target_repository.project.name == tprj
              found = 1
            end
          end
        end
        unless found
          render_error :status => 400, :errorcode => 'wrong_linked_package_source',
                       :message => "According to the source link of package #{pkg.project.name}/#{pkg.name} it would go to project #{tprj} which is not specified as release target."
          return
        end
      end

      newTargets << tprj
      newAction = action.dup
      newAction.source_package = pkg.name
      if action.action_type == :maintenance_incident
        newAction.target_releaseproject = releaseproject.name if releaseproject
      else
        newAction.target_project = tprj
        newAction.target_package = tpkg + incident_suffix
      end
      newAction.source_rev = rev if rev
      newactions << newAction
    end
    if action.action_type == :maintenance_release and found_patchinfo.nil? and params["ignore_build_state"].nil?
      render_error :status => 400, :errorcode => 'missing_patchinfo',
                   :message => "maintenance release request without patchinfo would release no binaries"
      return
    end

    # new packages (eg patchinfos) go to all target projects by default in maintenance requests
    newTargets.uniq!
    newPackages.each do |pkg|
      releaseTargets=nil
      if pkg.package_kinds.find_by_kind 'patchinfo'
        releaseTargets = Patchinfo.new.fetch_release_targets(pkg)
      end
      newTargets.each do |p|
        unless releaseTargets.blank?
          found=false
          releaseTargets.each do |rt|
            if rt['project'] == p
              found=true
              break
            end
          end
          next unless found
        end
        newAction = action.dup
        newAction.source_package = pkg.name
        unless action.action_type == :maintenance_incident
          newAction.target_project = p
          newAction.target_package = pkg.name + incident_suffix
        end
        newactions << newAction
      end
    end

    return newactions
  end


  def create_expand_targets(req)
    per_package_locking = false

    newactions = []
    oldactions = []

    # FIXME2.4 move this into action model
    req.bs_request_actions.each do |action|
      if [:maintenance_incident].include?(action.action_type)
        # find maintenance project
        maintenanceProject = nil
        if action.target_project
          maintenanceProject = Project.get_by_name action.target_project
        else
          # hardcoded default. frontends can lookup themselfs a different target via attribute search
          at = AttribType.find_by_name("OBS:MaintenanceProject")
          unless at
            render_error :status => 404, :errorcode => 'not_found',
                         :message => "Required OBS:Maintenance attribute not found, system not correctly deployed."
            return
          end
          maintenanceProject = Project.find_by_attribute_type(at).first
          unless maintenanceProject
            render_error :status => 400, :errorcode => 'project_not_found',
                         :message => "There is no project flagged as maintenance project on server and no target in request defined."
            return
          end
          action.target_project = maintenanceProject.name
        end
        unless maintenanceProject.project_type.to_s == "maintenance" or maintenanceProject.project_type.to_s == "maintenance_incident"
          render_error :status => 400, :errorcode => 'no_maintenance_project',
                       :message => "Maintenance incident requests have to go to projects of type maintenance or maintenance_incident"
          return
        end
      end

      # expand target_package
      if [:submit, :maintenance_release, :maintenance_incident].include?(action.action_type)
        next if action.target_package
        packages = Array.new
        if action.source_package
          packages << Package.get_by_project_and_name(action.source_project, action.source_package)
          per_package_locking = true
        else
          packages = Project.get_by_name(action.source_project).packages
        end

        na = create_expand_package(action, packages)
        return if na.nil?

        oldactions << action
        newactions.concat(na)
      end
    end

    oldactions.each { |a| req.bs_request_actions.destroy a }
    newactions.each { |a| req.bs_request_actions << a }

    return {per_package_locking: per_package_locking}

  end

  # FIXME2.4 move this into action model
  def check_action_permission(action)
    # find objects if specified or report error
    role=nil
    sprj=nil
    spkg=nil
    tprj=nil
    tpkg=nil
    if action.person_name
      # validate user object
      User.get_by_login(action.person_name)
    end
    if action.group_name
      # validate group object
      Group.get_by_title(action.group_name)
    end
    if action.role
      # validate role object
      role = Role.get_by_title(action.role)
    end
    if action.source_project
      sprj = Project.get_by_name action.source_project
      unless sprj
        render_error :status => 404, :errorcode => 'unknown_project',
                     :message => "Unknown source project #{action.source_project}"
        return false
      end
      unless sprj.class == Project
        render_error :status => 400, :errorcode => 'not_supported',
                     :message => "Source project #{action.source_project} is not a local project. This is not supported yet."
        return false
      end
      if action.source_package
        spkg = Package.get_by_project_and_name(action.source_project, action.source_package, use_source: true, follow_project_links: true)
      end
    end

    if action.target_project
      tprj = Project.get_by_name action.target_project
      if tprj.class == Project and tprj.project_type.to_sym == :maintenance_release and action.action_type == :submit
        render_error :status => 400, :errorcode => 'submit_request_rejected',
                     :message => "The target project #{action.target_project} is a maintenance release project, a submit action is not possible, please use the maintenance workflow instead."
        return false
      end
      if tprj.class == Project and (a = tprj.find_attribute("OBS", "RejectRequests") and a.values.first)
        if a.values.length < 2 or a.values.find_by_value(action.action_type)
          render_error :status => 403, :errorcode => 'request_rejected',
                       :message => "The target project #{action.target_project} is not accepting requests because: #{a.values.first.value.to_s}"
          return false
        end
      end
      if action.target_package
        if Package.exists_by_project_and_name(action.target_project, action.target_package) or [:delete, :change_devel, :add_role, :set_bugowner].include? action.action_type
          tpkg = Package.get_by_project_and_name action.target_project, action.target_package
        end

        if tpkg && (a = tpkg.find_attribute("OBS", "RejectRequests") and a.values.first)
          if a.values.length < 2 or a.values.find_by_value(action.action_type)
            render_error :status => 403, :errorcode => 'request_rejected',
                         :message => "The target package #{action.target_project} / #{action.target_package} is not accepting requests because: #{a.values.first.value.to_s}"
            return false
          end
        end
      end
    end

    # Type specific checks
    if action.action_type == :delete or action.action_type == :add_role or action.action_type == :set_bugowner
      #check existence of target
      unless tprj
        render_error :status => 404, :errorcode => 'unknown_project',
                     :message => "No target project specified"
        return false
      end
      if action.action_type == :add_role
        unless role
          render_error :status => 404, :errorcode => 'unknown_role',
                       :message => "No role specified"
          return false
        end
      end
    elsif [:submit, :change_devel, :maintenance_release, :maintenance_incident].include?(action.action_type)
      #check existence of source
      unless sprj
        # no support for remote projects yet, it needs special support during accept as well
        render_error :status => 404, :errorcode => 'unknown_project',
                     :message => "No source project specified"
        return false
      end

      if [:submit, :maintenance_incident, :maintenance_release].include? action.action_type
        # validate that the sources are not broken
        begin
          pr = ""
          if action.source_rev
            pr = "&rev=#{CGI.escape(action.source_rev)}"
          end
          # FIXM2.4 we have a Directory model
          url = "/source/#{CGI.escape(action.source_project)}/#{CGI.escape(action.source_package)}?expand=1" + pr
          c = backend_get(url)
          unless action.source_rev or params[:addrevision].blank?
            data = REXML::Document.new(c)
            action.source_rev = data.elements["directory"].attributes["srcmd5"]
          end
        rescue ActiveXML::Transport::Error
          render_error :status => 400, :errorcode => "expand_error",
                       :message => "The source of package #{action.source_project}/#{action.source_package}#{action.source_rev ? " for revision #{action.source_rev}" : ''} is broken"
          return false
        end
      end

      if action.action_type == :maintenance_incident
        if action.target_package
          render_error :status => 400, :errorcode => 'illegal_request',
                       :message => "Maintenance requests accept only projects as target"
          return false
        end
        raise "We should have expanded a target_project" unless action.target_project
        # validate project type
        prj = Project.get_by_name(action.target_project)
        unless ["maintenance", "maintenance_incident"].include? prj.project_type.to_s
          render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
                       :message => "incident projects shall only create below maintenance projects"
          return false
        end
      end

      # TODO continue refactoring
      if action.action_type == :maintenance_release
        action.check_permissions!
      end

      # source update checks
      if [:submit, :maintenance_incident].include?(action.action_type)
        # cleanup implicit home branches. FIXME3.0: remove this, the clients should do this automatically meanwhile
        if action.sourceupdate.nil? and action.target_project
          if "home:#{User.current.login}:branches:#{action.target_project}" == action.source_project
            action.sourceupdate = 'cleanup'
          end
        end
      end
      # allow cleanup only, if no devel package reference
      if action.sourceupdate == 'cleanup' && spkg
        spkg.can_be_deleted?
      end

      if action.action_type == :change_devel
        unless tpkg
          render_error :status => 404, :errorcode => 'unknown_package',
                       :message => "No target package specified"
          return false
        end
      end
    else
      action.check_permissions!
    end

    return true
  end

  # POST /request?cmd=create
  def create_create
    # refuse request creation for anonymous users
    if User.current.id == User.nobodyID
      render_error :status => 401, :errorcode => 'anonymous_user',
                   :message => "Anonymous user is not allowed to create requests"
      return
    end

    BsRequest.transaction do
      req = BsRequest.new_from_xml(request.body.read)
      # overwrite stuff
      req.commenter = User.current.login
      req.creator = User.current.login
      req.state = :new

      # expand release and submit request targets if not specified
      results = create_expand_targets(req) || return
      params[:per_package_locking] = results[:per_package_locking]

      # permission checks
      req.bs_request_actions.each do |action|
        check_action_permission(action) || return
      end

      # Autoapproval? Is the creator allowed to accept it?
      if req.accept_at
        check_request_change(req, {:cmd => "changestate", :newstate => "accepted"})
      end

      #
      # Find out about defined reviewers in target
      #
      # check targets for defined default reviewers
      reviewers = []

      req.bs_request_actions.each do |action|
        reviewers += action.default_reviewers

        action.create_post_permissions_hook(params)
      end

      # apply reviewers
      reviewers.uniq.each do |r|
        if r.class == User
          req.reviews.new :by_user => r.login
        elsif r.class == Group
          req.reviews.new :by_group => r.title
        elsif r.class == Project
          req.reviews.new :by_project => r.name
        else
          raise "Unknown review type" unless r.class == Package
          rev = req.reviews.new :by_project => r.project.name
          rev.by_package = r.name
        end
        req.state = :review
      end

      #
      # create the actual request
      #
      req.save!
      notify = req.notify_parameters
      Suse::Backend.send_notification('SRCSRV_REQUEST_CREATE', notify)

      req.reviews.each do |review|
        hermes_type, review_notify = review.notify_parameters(notify.dup)
        Suse::Backend.send_notification(hermes_type, review_notify) if hermes_type
      end

      # cache the diff (in the backend)
      req.bs_request_actions.each do |a|
        a.delay.webui_infos
      end

      render :text => req.render_xml, :content_type => 'text/xml'
    end
  end

  def command_diff
    valid_http_methods :post

    req = BsRequest.find params[:id]

    diff_text = ""
    action_counter = 0

    if params[:view] == 'xml'
      xml_request = ActiveXML::Node.new("<request id='#{req.id}'/>")
    else
      xml_request = nil
    end

    req.bs_request_actions.each do |action|
      withissues = false
      withissues = true if params[:withissues] == '1' || params[:withissues].to_s == 'true'
      begin
        action_diff = action.sourcediff(view: params[:view], withissues: withissues)
      rescue BsRequestAction::DiffError => e
        render_error :status => 404, :errorcode => 'diff_failure', :message => e.message and return
      end

      if xml_request
        # Inject backend-provided XML diff into action XML:
        builder = Nokogiri::XML::Builder.new
        action.render_xml(builder)
        a = xml_request.add_node(builder.to_xml)
        a.add_node(action_diff)
      else
        diff_text += action_diff
      end
    end

    if xml_request
      xml_request.set_attribute("actions", action_counter.to_s)
      send_data(xml_request.dump_xml, :type => "text/xml")
    else
      send_data(diff_text, :type => "text/plain")
    end
  end

  class PostRequestNoPermission < APIException
    setup "post_request_no_permission", 403
  end

  class PostRequestMissingParamater < APIException
    setup "post_request_missing_parameter", 403
  end

  class ReviewNotSpecified < APIException;
  end

  class ReviewChangeStateNoPermission < APIException
    setup "review_change_state_no_permission", 403
  end

  class GroupRequestSpecial < APIException
    setup "command_only_valid_for_group"
  end

  def check_request_change(req, params)

    # We do not support to revert changes from accepted requests (yet)
    if req.state == :accepted
      raise PostRequestNoPermission.new "change state from an accepted state is not allowed."
    end

    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if [:accepted, :superseded, :revoked].include? req.state
      if ["accepted", "declined", "superseded", "revoked"].include? params[:newstate]
        raise PostRequestNoPermission.new "set state to #{params[:newstate]} from a final state is not allowed."
      end
    end

    # enforce state to "review" if going to "new", when review tasks are open
    if params[:cmd] == "changestate"
      if params[:newstate] == "new" and req.reviews
        req.reviews.each do |r|
          params[:newstate] = "review" if r.state == :new
        end
      end
    end

    # adding and removing of requests is only allowed for groups
    if ["addrequest", "removerequest"].include? params[:cmd]
      if req.bs_request_actions.first.action_type != :group
        raise GroupRequestSpecial.new "Command #{params[:cmd]} is only valid for group requests"
      end
    end

    # Do not accept to skip the review, except force argument is given
    if params[:cmd] == "changestate"  and params[:newstate] == "accepted"
      if req.state == :review 
        unless params[:force]
i          raise PostRequestNoPermission.new "Request is in review state. You may use the force parameter to ignore this."
        end
      elsif req.state != :new
        raise PostRequestNoPermission.new "Request is not in new state. You may reopen it by setting it to new."
      end
    end

    # valid users and groups ?
    if params[:by_user]
      User.find_by_login!(params[:by_user])
    end
    if params[:by_group]
      Group.find_by_title!(params[:by_group])
    end

    # valid project or package ?
    if params[:by_project] and params[:by_package]
      pkg = Package.get_by_project_and_name(params[:by_project], params[:by_package])
    elsif params[:by_project]
      prj = Project.get_by_name(params[:by_project])
    end

    # generic permission checks
    permission_granted = false
    if User.current.is_admin?
      permission_granted = true
    elsif params[:newstate] == "deleted"
      raise PostRequestNoPermission.new "Deletion of a request is only permitted for administrators. Please revoke the request instead."
    elsif params[:cmd] == "addreview" or params[:cmd] == "setincident"
      unless [:review, :new].include? req.state
        raise ReviewChangeStateNoPermission.new "The request is not in state new or review"
      end
      # allow request creator to add further reviewers
      permission_granted = true if (req.creator == User.current.login or req.is_reviewer? User.current)
    elsif params[:cmd] == "changereviewstate"
      unless req.state == :review or req.state == :new
        raise ReviewChangeStateNoPermission.new "The request is neither in state review nor new"
      end
      found=nil
      if params[:by_user]
        unless User.current.login == params[:by_user]
          raise ReviewChangeStateNoPermission.new "review state change is not permitted for #{User.current.login}"
        end
        found=true
      end
      if params[:by_group]
        unless User.current.is_in_group?(params[:by_group])
          raise ReviewChangeStateNoPermission.new "review state change for group #{params[:by_group]} is not permitted for #{User.current.login}"
        end
        found=true
      end
      if params[:by_project]
        if params[:by_package]
          unless User.current.can_modify_package? pkg
            raise ReviewChangeStateNoPermission.new "review state change for package #{params[:by_project]}/#{params[:by_package]} is not permitted for #{User.current.login}"
          end
        elsif !User.current.can_modify_project? prj
          raise ReviewChangeStateNoPermission.new "review state change for project #{params[:by_project]} is not permitted for #{User.current.login}"
        end
        found=true
      end
      unless found
        raise ReviewNotSpecified.new "The review must specified via by_user, by_group or by_project(by_package) argument."
      end
      #
      permission_granted = true
    elsif req.state != :accepted and ["new", "review", "revoked", "superseded"].include?(params[:newstate]) and req.creator == User.current.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state == :declined and (params[:newstate] == "new" or params[:newstate] == "review") and req.commenter == User.current.login
      # people who declined a request shall also be able to reopen it
      permission_granted = true
    end

    if params[:newstate] == "superseded" and not params[:superseded_by]
      raise PostRequestMissingParamater.new "Supersed a request requires a 'superseded_by' parameter with the request id."
    end

    req.check_newstate! params.merge({extra_permission_checks: !permission_granted})
    return true
  end

  def command_addrequest
    command_changestate
  end

  def command_removerequest
    command_changestate
  end

  def command_setincident
    command_changestate # :cmd => "setincident",
                        # :incident
  end

  def command_addreview
    command_changestate # :cmd => "addreview",
                        # :by_user => params[:by_user], :by_group => params[:by_group], :by_project => params[:by_project], :by_package => params[:by_package]
  end

  def command_changereviewstate
    command_changestate # :cmd => "changereviewstate", :newstate => params[:newstate], :comment => params[:comment],
                        #:by_user => params[:by_user], :by_group => params[:by_group], :by_project => params[:by_project], :by_package => params[:by_package]
  end

  def command_changestate
    params[:user] = User.current.login
    required_parameters :id

    req = BsRequest.find params[:id]
    if not User.current or not User.current.login
      render_error :status => 403, :errorcode => "post_request_no_permission",
                   :message => "Action requires authentifacted user."
      return
    end

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and request.body
      params[:comment] = request.body.read
    end

    check_request_change(req, params) || return

    # permission granted for the request at this point

    # special command defining an incident to be merged
    params[:check_for_patchinfo] = false
    # all maintenance_incident actions go into the same incident project
    incident_project = nil
    req.bs_request_actions.each do |action|
      if action.action_type == :maintenance_incident

        if params[:cmd] == "setincident"
          tprj = Project.get_by_name action.target_project

          # use an existing incident
          if tprj.project_type.to_s == "maintenance"
            tprj = Project.get_by_name(action.target_project + ":" + params[:incident])
            action.target_project = tprj.name
            action.save!
          end
        elsif params[:cmd] == "changestate" and params[:newstate] == "accepted"
          tprj = Project.get_by_name action.target_project

          # the accept case, create a new incident if needed
          if tprj.project_type.to_s == "maintenance"
            # create incident if it is a maintenance project
            unless incident_project
              incident_project = create_new_maintenance_incident(tprj, nil, req).project
              params[:check_for_patchinfo] = true
            end
            unless incident_project.name.start_with?(tprj.name)
              render_error :status => 404, :errorcode => "multiple_maintenance_incidents",
                           :message => "This request handles different maintenance incidents, this is not allowed !"
              return
            end
            action.target_project = incident_project.name
            action.save!
          end
        end
      elsif action.action_type == :maintenance_release
        if params[:cmd] == "changestate" and params[:newstate] == "revoked"
          # unlock incident project in the soft way
          prj = Project.get_by_name(action.source_project)
          f = prj.flags.find_by_flag_and_status("lock", "enable")
          if f
            prj.flags.delete(f)
            prj.store({:comment => "Request #{} got revoked", :request => req.id, :lowprio => 1})
          end
        end
      end
    end

    case params[:cmd]
      when "setincident"
        # job done by changing target
        req.save!
        render_ok and return
      when "changestate"
        if params[:newstate] != "accepted"
          req.change_state(params[:newstate], params)
          render_ok and return
        end
      when "changereviewstate"
        req.change_review_state(params[:newstate], params)
        render_ok and return
      when "addreview"
        req.addreview(params)
        render_ok and return
      when "addrequest"
        req.bs_request_actions.first.addrequest(params)
        render_ok and return
      when "removerequest"
        req.bs_request_actions.first.removerequest(params)
        render_ok and return
      else
        raise "Unknown params #{params.inspect}"
    end

    # We have permission to change all requests inside, now execute
    req.bs_request_actions.each do |action|
      action.execute_accept(params)
    end

    # now do per request cleanup
    req.bs_request_actions.each do |action|
      action.per_request_cleanup(params)
    end

    # maintenance_incident request are modifying the request during accept
    req.change_state(params[:newstate], params)
    render_ok
  end

end
