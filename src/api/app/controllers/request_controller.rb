
require 'base64'

include MaintenanceHelper
include ProductHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  #TODO: allow PUT for non-admins
  before_filter :require_admin, :only => [:update, :destroy]

  # GET /request
  def index
    valid_http_methods :get

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
      ids = params[:ids].split(',').map {|i| i.to_i } if params[:ids]

      params.merge!({ states: states, types: types, review_states: review_states, roles: roles, ids: ids })
      rel = BsRequest.collection( params )
      rel = rel.includes([:reviews, :bs_request_histories])
      rel = rel.includes({ bs_request_actions: :bs_request_action_accept_info })
      rel = rel.order('bs_requests.id')

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
        BsRequest.select(:id).order(:id).each do |r|
          builder.entry name: r.id
        end
      end
      render :text => builder.to_xml, :content_type => "text/xml"
    end
  end

  validate_action :show => {:method => :get, :response => :request}

  # GET /request/:id
  def show
    valid_http_methods :get
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
        data = REXML::Document.new( backend_get("/source/#{URI.escape(tprj)}/#{URI.escape(ltpkg)}") )
        e = data.elements["directory/linkinfo"]
        if e
          suffix = ltpkg.gsub( /^#{e.attributes["package"]}/, '' )
          ltpkg = e.attributes["package"]
          tprj = e.attributes["project"]
          missing_ok_link=true if e.attributes["missingok"]
        else
          tprj = nil
        end
      end
      tpkg = tpkg.gsub(/#{suffix}$/, '') # strip distro specific extension
      
      # maintenance incidents need a releasetarget
      releaseproject = nil
      if action.action_type == :maintenance_incident
        
        unless pkg.package_kinds.find_by_kind 'patchinfo'
          if action.target_releaseproject
            releaseproject = Project.get_by_name action.target_releaseproject
          else
            unless tprj
              render_error :status => 400, :errorcode => 'no_maintenance_release_target',
              :message => "Maintenance incident request contains no defined release target project for package #{pkg.name}"
              return
            end
            releaseproject = Project.get_by_name tprj
          end
          # Automatically switch to update project
          if a = releaseproject.find_attribute("OBS", "UpdateProject") and a.values[0]
            releaseproject = Project.get_by_name a.values[0].value
          end
          unless releaseproject.project_type.to_sym == :maintenance_release
            render_error :status => 400, :errorcode => 'no_maintenance_release_target',
            :message => "Maintenance incident request contains release target project #{releaseproject.name} with invalid type #{releaseproject.project_type} for package #{pkg.name}"
            return
          end
        end
      end

      # do not allow release requests without binaries
      if action.action_type == :maintenance_release and data and params["ignore_build_state"].nil?
        entries = data.get_elements("directory/entry")
        entries.each do |entry|
          next unless entry.attributes["name"] == "_patchinfo"
          # check for build state and binaries
          state = REXML::Document.new( backend_get("/build/#{URI.escape(pkg.project.name)}/_result") )
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
            if repo and repo.architectures.first
              # skip excluded patchinfos
              status = state.get_elements("/resultlist/result[@repository='#{repo.name}' and @arch='#{repo.architectures.first.name}']").first
              unless status and s=status.get_elements("status[@package='#{pkg.name}']").first and s.attributes['code'] == "excluded"
                binaries = REXML::Document.new( backend_get("/build/#{URI.escape(pkg.project.name)}/#{URI.escape(repo.name)}/#{URI.escape(repo.architectures.first.name)}/#{URI.escape(pkg.name)}") )
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
        unless e and Package.exists_by_project_and_name( tprj, tpkg, follow_project_links: true, allow_remote_packages: false)
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
      newAction = BsRequestAction.new
      newAction.initialize_dup(action)
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
        answer = Suse::Backend.get("/source/#{URI.escape(pkg.project.name)}/#{URI.escape(pkg.name)}/_patchinfo")
        data = ActiveXML::Node.new(answer.body)
        # validate _patchinfo for completeness
        unless data
          render_error :status => 400, :errorcode => 'incomplete_patchinfo',
          :message => "The _patchinfo file is not parseble"
          return
        end
        if data.rating.nil? or data.rating.text.blank?
          render_error :status => 400, :errorcode => 'incomplete_patchinfo',
          :message => "The _patchinfo has no rating set"
          return
        end
        if data.category.nil? or data.category.text.blank?
          render_error :status => 400, :errorcode => 'incomplete_patchinfo',
          :message => "The _patchinfo has no category set"
          return
        end
        if data.summary.nil? or data.summary.text.blank?
          render_error :status => 400, :errorcode => 'incomplete_patchinfo',
          :message => "The _patchinfo has no summary set"
          return
        end
        # a patchinfo may limit the targets
        if data.releasetarget
          releaseTargets = Array.new unless releaseTargets
          data.each_releasetarget do |rt|
            releaseTargets << rt
          end
        end
      end
      newTargets.each do |p|
        if releaseTargets
          found=false
          releaseTargets.each do |rt|
            if rt.project == p
              found=true
              break
            end
          end
          next unless found
        end
        newAction = BsRequestAction.new
        newAction.initialize_dup(action)
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
      if [ :maintenance_incident ].include?(action.action_type)
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
          maintenanceProject = Project.find_by_attribute_type( at ).first
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
      if [ :submit, :maintenance_release, :maintenance_incident ].include?(action.action_type)
        next if action.target_package
        packages = Array.new
        if action.source_package
          packages << Package.get_by_project_and_name( action.source_project, action.source_package )
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

    return { per_package_locking: per_package_locking }

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
      User.find_by_login!(action.person_name)
    end
    if action.group_name
      # validate group object
      Group.find_by_title!(action.group_name)
    end
    if action.role
      # validate role object
      role = Role.find_by_title!(action.role)
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
    elsif [ :submit, :change_devel, :maintenance_release, :maintenance_incident ].include?(action.action_type)
      #check existence of source
      unless sprj
        # no support for remote projects yet, it needs special support during accept as well
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "No source project specified"
        return false
      end

      if [ :submit, :maintenance_incident, :maintenance_release ].include? action.action_type
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
            data = REXML::Document.new( c )
            action.source_rev = data.elements["directory"].attributes["srcmd5"]
          end
        rescue ActiveXML::Transport::Error
          render_error :status => 400, :errorcode => "expand_error",
            :message => "The source of package #{action.source_project}/#{action.source_package}#{action.source_rev ? " for revision #{action.source_rev}":''} is broken"
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
        unless [ "maintenance", "maintenance_incident" ].include? prj.project_type.to_s
          render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
          :message => "incident projects shall only create below maintenance projects"
          return false
        end
      end

      if action.action_type == :maintenance_release
        # get sure that the releasetarget definition exists or we release without binaries
        prj = Project.get_by_name(action.source_project)
        prj.repositories.includes(:release_targets).each do |repo|
          unless repo.release_targets.size > 0
            render_error :status => 400, :errorcode => "repository_without_releasetarget",
            :message => "Release target definition is missing in #{prj.name} / #{repo.name}"
            return false
          end
          unless repo.architectures.size > 0
            render_error :status => 400, :errorcode => "repository_without_architecture",
            :message => "Repository has no architecture #{prj.name} / #{repo.name}"
            return false
          end
          repo.release_targets.each do |rt|
            unless repo.architectures.first == rt.target_repository.architectures.first
              render_error :status => 400, :errorcode => "architecture_order_missmatch",
              :message => "Repository and releasetarget have not the same architecture on first position: #{prj.name} / #{repo.name}"
              return false
            end
          end
        end

        # check for open release requests with same target, the binaries can't get merged automatically
        # either exact target package match or with same prefix (when using the incident extension)

        # patchinfos don't get a link, all others should not conflict with any other
        # FIXME2.4 we have a directory model
        answer = Suse::Backend.get "/source/#{CGI.escape(action.source_project)}/#{CGI.escape(action.source_package)}"
        xml = REXML::Document.new(answer.body.to_s)
        rel = BsRequest.where(state: [:new, :review]).joins(:bs_request_actions)
        rel = rel.where(bs_request_actions: { target_project: action.target_project })
        if xml.elements["/directory/entry/@name='_patchinfo'"]
          rel = rel.where(bs_request_actions: { target_package: action.target_package } )
        else
          tpkgprefix = action.target_package.gsub(/\.[^\.]*$/, '')
          rel = rel.where("bs_request_actions.target_package = ? or bs_request_actions.target_package like '#{tpkgprefix}.%'", action.target_package)
        end

        # run search
        open_ids = rel.select("bs_requests.id").all.map { |r| r.id }

        unless open_ids.blank?
          render_error :status => 400, :errorcode => "open_release_requests",
          :message => "The following open requests have the same target #{action.target_project} / #{tpkgprefix}: " + open_ids.join(', ')
          return false
        end
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
      render_error :status => 403, :errorcode => "create_unknown_request",
      :message => "Request type is unknown '#{action.action_type}'"
      return false
    end

    return true
  end

  class LackingReleaseMaintainership < APIException
    setup "lacking_maintainership", 403
  end

  # POST /request?cmd=create
  def create_create
    # refuse request creation for anonymous users
    if User.current == http_anonymous_user
      render_error :status => 401, :errorcode => 'anonymous_user',
        :message => "Anonymous user is not allowed to create requests"
      return
    end

    req = BsRequest.new_from_xml(request.body.read)
    # overwrite stuff
    req.commenter = User.current.login
    req.creator = User.current.login
    req.state = :new
    
    # expand release and submit request targets if not specified
    results = create_expand_targets(req) || return
    per_package_locking = results[:per_package_locking]

    # permission checks
    req.bs_request_actions.each do |action|
      check_action_permission(action) || return
    end

    #
    # Find out about defined reviewers in target
    #
    # check targets for defined default reviewers
    reviewers = []

    req.bs_request_actions.each do |action|
      reviewers += action.default_reviewers

      if action.action_type == :maintenance_release
        # creating release requests is also locking the source package, therefore we require write access there.
        spkg = Package.find_by_project_and_name action.source_project, action.source_package
        unless spkg or not User.current.can_modify_package? spkg
          raise LackingReleaseMaintainership.new "Creating a release request action requires maintainership in source package"
        end
        object = nil
        if per_package_locking
          object = spkg
        else
          object = spkg.project
        end
        unless object.enabled_for?('lock', nil, nil)
          f = object.flags.find_by_flag_and_status("lock", "disable")
          object.flags.delete(f) if f # remove possible existing disable lock flag
          object.flags.create(:status => "enable", :flag => "lock")
          object.store
        end
      end
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

  class ReviewNotSpecified < APIException
    setup "review_not_specified", 400
  end
  
  class PostRequestMissingParamater < APIException
    setup "post_request_missing_parameter", 403
  end

  class ReviewChangeStateNoPermission < APIException
    setup "review_change_state_no_permission", 403
  end

  def check_request_change(req, params)
    
    # We do not support to revert changes from accepted requests (yet)
    if req.state == :accepted
      raise PostRequestNoPermission.new "change state from an accepted state is not allowed."
    end

    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if [ :accepted, :superseded, :revoked ].include? req.state
      if [ "accepted", "declined", "superseded", "revoked" ].include? params[:newstate]
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
    
    # Do not accept to skip the review, except force argument is given
    if params[:newstate] == "accepted"
      if params[:cmd] == "changestate" and req.state == :review and not params[:force]
        raise PostRequestNoPermission.new "Request is in review state. You may use the force parameter to ignore this."
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
      unless [ :review, :new ].include? req.state
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
    elsif req.state != "accepted" and ["new","review","revoked","superseded"].include?(params[:newstate]) and 
        req.creator == User.current.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state == "declined" and (params[:newstate] == "new" or params[:newstate] == "review") and req.state.who == User.current.login
      # people who declined a request shall also be able to reopen it
      permission_granted = true
    end

    if params[:newstate] == "superseded" and not params[:superseded_by]
      raise PostRequestMissingParamater.new "Supersed a request requires a 'superseded_by' parameter with the request id."
    end

    req.check_newstate! params.merge({extra_permission_checks: !permission_granted})
    return true
  end

  def command_setincident
     command_changestate# :cmd => "setincident",
                       # :incident
  end

  def command_addreview
     command_changestate# :cmd => "addreview",
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
    check_for_patchinfo = false
    # all maintenance_incident actions go into the same incident project
    incident_project = nil
    req.bs_request_actions.each do |action|
      if action.action_type == :maintenance_incident
        tprj = Project.get_by_name action.target_project

        if params[:cmd] == "setincident"
          # use an existing incident
          if tprj.project_type.to_s == "maintenance"
            tprj = Project.get_by_name(action.target_project + ":" + params[:incident])
            action.target_project = tprj.name
            action.save!
          end
        elsif params[:cmd] == "changestate" and params[:newstate] == "accepted"
          # the accept case, create a new incident if needed
          if tprj.project_type.to_s == "maintenance"
            # create incident if it is a maintenance project
            unless incident_project
              incident_project = create_new_maintenance_incident(tprj, nil, req ).project
              check_for_patchinfo = true
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

    # job done by changing target
    if params[:cmd] == "setincident"
      req.save!
      render_ok
      return
    end

    unless params[:cmd] == "changestate" and params[:newstate] == "accepted"
      case params[:cmd]
      when "changestate"
        req.change_state(params[:newstate], params)
        render_ok
      when "changereviewstate"
        req.change_review_state(params[:newstate], params)
        render_ok
      when "addreview"
        req.addreview(params)
        render_ok
      else
        raise "Unknown params #{params.inspect}"
      end
    return
    end

    # have a unique time stamp for release
    acceptTimeStamp = Time.now
    projectCommit = {}

    # use the request description as comments for history
    source_history_comment = req.description

    # We have permission to change all requests inside, now execute
    req.bs_request_actions.each do |action|
      # general source update options exists ?
      sourceupdate = action.sourceupdate
  
      if action.action_type == :set_bugowner
          object = Project.find_by_name!(action.target_project)
          bugowner = Role.get_by_title("bugowner")
          if action.target_package
            object = object.packages.find_by_name!(action.target_package)
            PackageUserRoleRelationship.where("db_package_id = ? AND role_id = ?", object, bugowner).each do |r|
              r.destroy
            end
          else
            ProjectUserRoleRelationship.where("db_project_id = ? AND role_id = ?", object, bugowner).each do |r|
              r.destroy
            end
          end
          object.add_user( action.person_name, bugowner )
          object.store
      elsif action.action_type == :add_role
          object = Project.find_by_name(action.target_project)
          if action.target_package
             object = object.packages.find_by_name(action.target_package)
          end
          if action.person_name
             role = Role.find_by_title!(action.role)
             object.add_user( action.person_name, role )
          end
          if action.group_name
             role = Role.find_by_title!(action.role)
             object.add_group( action.group_name, role )
          end
          object.store
      elsif action.action_type == :change_devel
          target_project = Project.get_by_name(action.target_project)
          target_package = target_project.packages.find_by_name(action.target_package)
          target_package.develpackage = Package.get_by_project_and_name(action.source_project, action.source_package)
          begin
            target_package.resolve_devel_package
            target_package.store
          rescue Package::CycleError => e
            # FIXME: this needs to be checked before, or we have a half submitted request
            render_error :status => 403, :errorcode => "devel_cycle", :message => e.message
            return
          end
      elsif action.action_type == :submit
          cp_params = {
            :cmd => "copy",
            :user => User.current.login,
            :oproject => action.source_project,
            :opackage => action.source_package,
            :noservice => 1,
            :requestid => params[:id],
            :comment => source_history_comment,
	    :withacceptinfo => 1
          }
          cp_params[:orev] = action.source_rev if action.source_rev
          cp_params[:dontupdatesource] = 1 if sourceupdate == "noupdate"
          unless action.updatelink
            cp_params[:expand] = 1
            cp_params[:keeplink] = 1
          end

          #create package unless it exists already
          target_project = Project.get_by_name(action.target_project)
          if action.target_package
            target_package = target_project.packages.find_by_name(action.target_package)
          else
            target_package = target_project.packages.find_by_name(action.source_package)
          end

          relinkSource=false
          unless target_package
            # check for target project attributes
            initialize_devel_package = target_project.find_attribute( "OBS", "InitializeDevelPackage" )
            # create package in database
            linked_package = target_project.find_package(action.target_package)
            if linked_package
              newxml = Xmlhash.parse(linked_package.to_axml)
            else
              answer = Suse::Backend.get("/source/#{URI.escape(action.source_project)}/#{URI.escape(action.source_package)}/_meta")
              newxml = Xmlhash.parse(answer.body)
            end
            newxml['name'] = action.target_package
            target_package = target_project.packages.new(name: newxml['name'])
            target_package.update_from_xml(newxml)
            if !linked_package
              target_package.flags.destroy_all
              target_package.develpackage = nil
              if initialize_devel_package
                target_package.develpackage = Package.find_by_project_and_name( action.source_project, action.source_package )
                relinkSource=true
              end
            end
            target_package.remove_all_persons
            target_package.remove_all_groups
            target_package.store

            # check if package was available via project link and create a branch from it in that case
            if linked_package
              h = {}
              h[:cmd] = "branch"
              h[:user] = User.current.login
              h[:comment] = "empty branch to project linked package"
              h[:requestid] = params[:id]
              h[:noservice] = "1"
              h[:oproject] = linked_package.project.name
              h[:opackage] = linked_package.name
              cp_path = "/source/#{CGI.escape(action.target_project)}/#{CGI.escape(action.target_package)}"
              cp_path << build_query_from_hash(h, [:user, :comment, :cmd, :oproject, :opackage, :requestid, :orev, :noservice])
              Suse::Backend.post cp_path, nil
            end
          end

          cp_path = "/source/#{action.target_project}/#{action.target_package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :keeplink, :comment, :requestid, :dontupdatesource, :noservice, :withacceptinfo])
          result = Suse::Backend.post cp_path, nil
	  result = Xmlhash.parse(result.body)
	  action.set_acceptinfo(result["acceptinfo"])

          target_package.sources_changed

          # cleanup source project
          if relinkSource and not sourceupdate == "noupdate"
            sourceupdate = nil
            # source package got used as devel package, link it to the target
            # re-create it via branch , but keep current content...
            h = {}
            h[:cmd] = "branch"
            h[:user] = User.current.login
            h[:comment] = "initialized devel package after accepting #{params[:id]}"
            h[:requestid] = params[:id]
            h[:keepcontent] = "1"
            h[:noservice] = "1"
            h[:oproject] = action.target_project
            h[:opackage] = action.target_package
            cp_path = "/source/#{CGI.escape(action.source_project)}/#{CGI.escape(action.source_package)}"
            cp_path << build_query_from_hash(h, [:user, :comment, :cmd, :oproject, :opackage, :requestid, :keepcontent])
            Suse::Backend.post cp_path, nil
          end

      elsif action.action_type == :delete
          if action.target_repository
            prj = Project.get_by_name(action.target_project)
            r=Repository.find_by_project_and_repo_name(action.target_project, action.target_repository)
            unless r
              render_error :status => 404, :errorcode => "repository_missing", :message => "The repository #{action.target_project} / #{action.target_repository} does not exist"
	      return
            end
            r.destroy
            prj.store(params)
          else
            if action.target_package
              package = Package.get_by_project_and_name(action.target_project, action.target_package, use_source: true, follow_project_links: false)
              package.destroy
              delete_path = "/source/#{action.target_project}/#{action.target_package}"
            else
              project = Project.get_by_name(action.target_project)
              project.destroy
              delete_path = "/source/#{action.target_project}"
            end
            h = { :user => User.current.login, :comment => source_history_comment, :requestid => params[:id] }
            delete_path << build_query_from_hash(h, [:user, :comment, :requestid])
            Suse::Backend.delete delete_path
          end
      elsif action.action_type == :maintenance_incident
        # create or merge into incident project
        source = nil
        if action.source_package
          source = Package.get_by_project_and_name(action.source_project, action.source_package)
        else
          source = Project.get_by_name(action.source_project)
        end

        incident_project = Project.get_by_name(action.target_project)

        # the incident got created before
        merge_into_maintenance_incident(incident_project, source, action.target_releaseproject, req)

        # update action with real target project
        action.target_project = incident_project.name

      elsif action.action_type == :maintenance_release
        pkg = Package.get_by_project_and_name(action.source_project, action.source_package)
#FIXME2.5: support limiters to specified repositories
        release_package(pkg, action.target_project, action.target_package, action.source_rev, nil, nil, acceptTimeStamp, req)
        projectCommit[action.target_project] = action.source_project
      end

      # general source cleanup, used in submit and maintenance_incident actions
      if sourceupdate == "cleanup"
        # cleanup source project
        source_project = Project.find_by_name(action.source_project)
        delete_path = nil
        if source_project.packages.count == 1 or action.source_package.nil?
          # remove source project, if this is the only package and not the user's home project
          if source_project.name != "home:" + user.login
            source_project.destroy
            delete_path = "/source/#{action.source_project}"
          end
        else
          # just remove one package
          source_package = source_project.packages.find_by_name(action.source_package)
          source_package.destroy
          delete_path = "/source/#{action.source_project}/#{action.source_package}"
        end
        del_params = {
          :user => User.current.login,
          :requestid => params[:id],
          :comment => source_history_comment
        }
        delete_path << build_query_from_hash(del_params, [:user, :comment, :requestid])
        Suse::Backend.delete delete_path
      end
  
      if action.target_package == "_product"
        update_product_autopackages action.target_project
      end
    end

    # log release events once in target project
    projectCommit.each do |tprj, sprj|
      commit_params = {
        :cmd => "commit",
        :user => User.current.login,
        :requestid => params[:id],
        :rev => "latest",
        :comment => "Release from project: " + sprj
      }
      commit_path = "/source/#{URI.escape(tprj)}/_project"
      commit_path << build_query_from_hash(commit_params, [:cmd, :user, :comment, :requestid, :rev])
      Suse::Backend.post commit_path, nil
    end

    # create a patchinfo if missing and incident has just been created
    if check_for_patchinfo and !incident_project.packages.where(name: "patchinfo").first
      incident_project.create_patchinfo_from_request(req)
    end 

    # maintenance_incident request are modifying the request during accept
    req.change_state(params[:newstate], params)
    render_ok
  end

end

