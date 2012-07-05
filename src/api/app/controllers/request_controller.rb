require 'base64'

include MaintenanceHelper
include ProductHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  #TODO: allow PUT for non-admins
  before_filter :require_admin, :only => [:update]

  # GET /request
  def index
    valid_http_methods :get

    if params[:view] == "collection"
      #FIXME: Move this code into a model so that it can be reused in other controllers

      # Do not allow a full collection to avoid server load
      if params[:project].blank? and params[:user].blank? and params[:states].blank? and params[:types].blank? and params[:reviewstates].blank?
       render_error :status => 404, :errorcode => 'require_filter',
         :message => "This call requires at least one filter, either by user, project or package or states or types or reviewstates"
       return
      end

      # convert comma seperated values into arrays
      roles = []
      states = []
      types = []
      review_states = [ "new" ]
      roles = params[:roles].split(',') if params[:roles]
      types = params[:types].split(',') if params[:types]
      states = params[:states].split(',') if params[:states]
      review_states = params[:reviewstates].split(',') if params[:reviewstates]

      rel = BsRequest.joins(:bs_request_actions)
      rel = rel.includes([:reviews, :bs_request_histories])

      # filter for request state(s)
      unless states.blank?
        rel = rel.where("bs_requests.state in (?)", states)
      end

      # Filter by request type (submit, delete, ...)
      unless types.blank?
        rel = rel.where("bs_request_actions.action_type in (?)", types)
      end

      # FIXME2.4 this needs to be protected from SQL injection before 2.4

      unless params[:project].blank?
        inner_or = []

        if params[:package].blank?
          if roles.count == 0 or roles.include? "source"
            if params[:subprojects].blank?
              inner_or << "bs_request_actions.source_project='#{params[:project]}'"
            else
              inner_or << "(bs_request_actions.source_project like '#{params[:project]}:%')"
            end
          end
          if roles.count == 0 or roles.include? "target"
            if params[:subprojects].blank?
              inner_or << "bs_request_actions.target_project='#{params[:project]}'"
            else
              inner_or << "(bs_request_actions.target_project like '#{params[:project]}:%')"
            end
          end

          if roles.count == 0 or roles.include? "reviewer"
            if states.count == 0 or states.include? "review"
              review_states.each do |r|
                inner_or << "(reviews.state='#{r}' and reviews.by_project='#{params[:project]}')"
              end
            end
          end
        else
          if roles.count == 0 or roles.include? "source"
            inner_or << "(bs_request_actions.source_project='#{params[:project]}' and bs_request_actions.source_package='#{params[:package]}')" 
          end
          if roles.count == 0 or roles.include? "target"
            inner_or << "(bs_request_actions.target_project='#{params[:project]}' and bs_request_actions.target_package='#{params[:package]}')" 
          end
          if roles.count == 0 or roles.include? "reviewer"
            if states.count == 0 or states.include? "review"
              review_states.each do |r|
                inner_or << "(reviews.state='#{r}' and reviews.by_project='#{params[:project]}' and reviews.by_package='#{params[:package]}')"
              end
            end
          end
        end

        if inner_or.count > 0
          rel = rel.where(inner_or.join(" or "))
        end
      end

      if params[:user]
        inner_or = []
        user = User.get_by_login(params[:user])
        # user's own submitted requests
        if roles.count == 0 or roles.include? "creator"
          inner_or << "bs_requests.creator = '#{user.login}'"
        end

        # find requests where user is maintainer in target project
        if roles.count == 0 or roles.include? "maintainer"
          names = user.involved_projects.map { |p| p.name }
          inner_or << "bs_request_actions.target_project in ('" + names.join("','") + "')"

          ## find request where user is maintainer in target package, except we have to project already
          user.involved_packages.each do |ip|
            inner_or << "(bs_request_actions.target_project='#{ip.db_project.name}' and bs_request_actions.target_package='#{ip.name}')"
          end
        end

        if roles.count == 0 or roles.include? "reviewer"
          review_states.each do |r|
            
            # requests where the user is reviewer or own requests that are in review by someone else
            or_in_and = [ "reviews.by_user='#{user.login}'" ]
            # include all groups of user
            usergroups = user.groups.map { |g| "'#{g.title}'" }
            or_in_and << "reviews.by_group in (#{usergroups.join(',')})" unless usergroups.blank?

            # find requests where user is maintainer in target project
            userprojects = user.involved_projects.select("db_projects.name").map { |p| "'#{p.name}'" }
            or_in_and << "reviews.by_project in (#{userprojects.join(',')})" unless userprojects.blank?

            ## find request where user is maintainer in target package, except we have to project already
            user.involved_packages.select("name,db_project_id").includes(:db_project).each do |ip|
              or_in_and << "(reviews.by_project='#{ip.db_project.name}' and reviews.by_package='#{ip.name}')"
            end

            inner_or << "(reviews.state='#{r}' and (#{or_in_and.join(" or ")}))"
          end
        end

        unless inner_or.empty?
          rel = rel.where(inner_or.join(" or "))
        end
      end

      # Pagination: Discard 'offset' most recent requests (useful with 'count')
      if params[:offset]
        # TODO: Backend XPath engine needs better range support
      end
      # Pagination: Return only 'count' requests
      if params[:count]
        # TODO: Backend XPath engine needs better range support
      end

      xml = ActiveXML::Base.new "<collection/>"
      matches=0
      rel.includes({ bs_request_actions: :bs_request_action_accept_info }, :bs_request_histories).each do |r|
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

      send_data(req.render_xml, :type => "text/xml")
    end
  end

  # DELETE /request/:id
  #def destroy
  # Do we want to allow to delete requests at all ?
  #end

  private

  #
  # find default reviewers of a project/package via role
  # 
  def find_reviewers(obj)
    # obj can be a project or package object
    reviewers = Array.new(0)
    prj = nil

    # check for reviewers in a package first
    if obj.class == DbProject
      prj = obj
    elsif obj.class == DbPackage
      if defined? obj.package_user_role_relationships
        obj.package_user_role_relationships.joins(:role).where("roles.title = 'reviewer'").select("bs_user_id").each do |r|
          reviewers << User.find(r.bs_user_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_user_role_relationships
      prj.project_user_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
        reviewers << User.find(r.bs_user_id)
      end
    end
    return reviewers
  end

  def find_review_groups(obj)
    # obj can be a project or package object
    review_groups = Array.new(0)
    prj = nil
    # check for reviewers in a package first
    if obj.class == DbProject
      prj = obj
    elsif obj.class == DbPackage
      if defined? obj.package_group_role_relationships
        obj.package_group_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
          review_groups << Group.find(r.bs_group_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_group_role_relationships
      prj.project_group_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
        review_groups << Group.find(r.bs_group_id)
      end
    end
    return review_groups
  end

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
      tprj = pkg.db_project.name
      tpkg = ltpkg = pkg.name
      rev = action.source_rev
      data = nil
      missing_ok_link=false
      suffix = ""
      while tprj == pkg.db_project.name
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
        
        unless pkg.db_package_kinds.find_by_kind 'patchinfo'
          if action.target_releaseproject
            releaseproject = DbProject.get_by_name action.target_releaseproject
          else
            unless tprj
              render_error :status => 400, :errorcode => 'no_maintenance_release_target',
              :message => "Maintenance incident request contains no defined release target project for package #{pkg.name}"
              return
            end
            releaseproject = DbProject.get_by_name tprj
          end
          # Automatically switch to update project
          if a = releaseproject.find_attribute("OBS", "UpdateProject") and a.values[0]
            releaseproject = DbProject.get_by_name a.values[0].value
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
          state = REXML::Document.new( backend_get("/build/#{URI.escape(pkg.db_project.name)}/_result") )
          repos = state.get_elements("/resultlist/result[@project='#{pkg.db_project.name}'')]")
          unless repos
            render_error :status => 400, :errorcode => 'build_not_finished',
            :message => "The project'#{pkg.db_project.name}' has no building repositories"
            return
          end
          repos.each do |repo|
            unless ["finished", "publishing", "published", "unpublished"].include? repo.attributes['state']
              render_error :status => 400, :errorcode => 'build_not_finished',
              :message => "The repository '#{pkg.db_project.name}' / '#{repo.attributes['repository']}' / #{repo.attributes['arch']}"
              return
            end
          end
          pkg.db_project.repositories.each do |repo|
            if repo and repo.architectures.first
              # skip excluded patchinfos
              status = state.get_elements("/resultlist/result[@repository='#{repo.name}' and @arch='#{repo.architectures.first.name}']").first
              unless status and s=status.get_elements("status[@package='#{pkg.name}']").first and s.attributes['code'] == "excluded"
                binaries = REXML::Document.new( backend_get("/build/#{URI.escape(pkg.db_project.name)}/#{URI.escape(repo.name)}/#{URI.escape(repo.architectures.first.name)}/#{URI.escape(pkg.name)}") )
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
        unless e and DbPackage.exists_by_project_and_name( tprj, tpkg, true, false)
          if action.action_type == :maintenance_release
            newPackages << pkg
            pkg.db_project.repositories.includes(:release_targets).each do |repo|
              repo.release_targets.each do |rt|
                newTargets << rt.target_repository.db_project.name
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
        pkg.db_project.repositories.includes(:release_targets).each do |repo|
          repo.release_targets.each do |rt|
            if rt.target_repository.db_project.name == tprj
              found = 1
            end
          end
        end
        unless found
          render_error :status => 400, :errorcode => 'wrong_linked_package_source',
          :message => "According to the source link of package #{pkg.db_project.name}/#{pkg.name} it would go to project #{tprj} which is not specified as release target."
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
      if pkg.db_package_kinds.find_by_kind 'patchinfo'
        answer = Suse::Backend.get("/source/#{URI.escape(pkg.db_project.name)}/#{URI.escape(pkg.name)}/_patchinfo")
        data = ActiveXML::Base.new(answer.body)
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

    per_package_locking = nil

    newactions = []
    oldactions = []

    # FIXME2.4 move this into action model
    req.bs_request_actions.each do |action|
      if [ :maintenance_incident ].include?(action.action_type)
        # find maintenance project
        maintenanceProject = nil
        if action.target_project
          maintenanceProject = DbProject.get_by_name action.target_project 
        else
          # hardcoded default. frontends can lookup themselfs a different target via attribute search
          at = AttribType.find_by_name("OBS:MaintenanceProject")
          unless at
            render_error :status => 404, :errorcode => 'not_found',
              :message => "Required OBS:Maintenance attribute not found, system not correctly deployed."
            return
          end
          maintenanceProject = DbProject.find_by_attribute_type( at ).first
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
          packages << DbPackage.get_by_project_and_name( action.source_project, action.source_package )
          per_package_locking = 1
        else
          packages = DbProject.get_by_name(action.source_project).db_packages
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
      sprj = DbProject.get_by_name action.source_project
      unless sprj
        render_error :status => 404, :errorcode => 'unknown_project',
        :message => "Unknown source project #{action.source_project}"
        return false
      end
      unless sprj.class == DbProject
        render_error :status => 400, :errorcode => 'not_supported',
        :message => "Source project #{action.source_project} is not a local project. This is not supported yet."
        return false
      end
      if action.source_package
        spkg = DbPackage.get_by_project_and_name(action.source_project, action.source_package, true, true)
      end
    end

    if action.target_project
      tprj = DbProject.get_by_name action.target_project
      if tprj.class == DbProject and tprj.project_type.to_sym == :maintenance_release and action.action_type == :submit
        render_error :status => 400, :errorcode => 'submit_request_rejected',
        :message => "The target project #{action.target_project} is a maintenance release project, a submit action is not possible, please use the maintenance workflow instead."
        return false
      end
      if tprj.class == DbProject and (a = tprj.find_attribute("OBS", "RejectRequests") and a.values.first)
        render_error :status => 403, :errorcode => 'request_rejected',
        :message => "The target project #{action.target_project} is not accepting requests because: #{a.values.first.value.to_s}"
        return false
      end
      if action.target_package
        if DbPackage.exists_by_project_and_name(action.target_project, action.target_package) or [:delete, :change_devel, :add_role, :set_bugowner].include? action.action_type
          tpkg = DbPackage.get_by_project_and_name action.target_project, action.target_package
        end
        
        if tpkg && (a = tpkg.find_attribute("OBS", "RejectRequests") and a.values.first)
          render_error :status => 403, :errorcode => 'request_rejected',
          :message => "The target package #{action.target_project} / #{action.target_package} is not accepting requests because: #{a.values.first.value.to_s}"
          return false
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
          :message => "The source of package #{action.source_project}/#{action.source_package} rev=#{action.source_rev} are broken"
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
        prj = DbProject.get_by_name(action.target_project)
        unless [ "maintenance", "maintenance_incident" ].include? prj.project_type.to_s
          render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
          :message => "incident projects shall only create below maintenance projects"
          return false
        end
      end

      if action.action_type == :maintenance_release
        # get sure that the releasetarget definition exists or we release without binaries
        prj = DbProject.get_by_name(action.source_project)
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
          rel = rel.where("bs_request_actions.target_package = ? or bs_request_actions.target_package like '#{tpkgprefix}%'", action.target_package)
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
          if "home:#{@http_user.login}:branches:#{action.target_project}" == action.source_project
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

  # POST /request?cmd=create
  def create_create
    # refuse request creation for anonymous users
    if @http_user == http_anonymous_user
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
      check_action_permission(action)  || return
    end

    #
    # Find out about defined reviewers in target
    #
    # check targets for defined default reviewers
    reviewers = []
    review_groups = []
    review_packages = []

    req.bs_request_actions.each do |action|
      tprj = nil
      tpkg = nil

      if action.target_project
        tprj = DbProject.find_by_name action.target_project
        if action.target_package
          if action.action_type == :maintenance_release
            # use orignal/stripped name and also GA projects for maintenance packages
            tpkg = tprj.find_package action.target_package.gsub(/\.[^\.]*$/, '')
          else
            # just the direct affected target
            tpkg = tprj.db_packages.find_by_name action.target_package
          end
        else
          if action.source_package
            tpkg = tprj.db_packages.find_by_name action.source_package
          end
        end
      end
      if action.source_project
        # if the user is not a maintainer if current devel package, the current maintainer gets added as reviewer of this request
        if action.action_type == :change_devel and tpkg.develpackage and not @http_user.can_modify_package?(tpkg.develpackage, 1)
          review_packages.push({ :by_project => tpkg.develpackage.db_project.name, :by_package => tpkg.develpackage.name })
        end

        if action.action_type == :maintenance_release
          # creating release requests is also locking the source package, therefore we require write access there.
          spkg = DbPackage.find_by_project_and_name action.source_project, action.source_package
          unless spkg or not @http_user.can_modify_package? spkg
            render_error :status => 403, :errorcode => "lacking_maintainership",
              :message => "Creating a release request action requires maintainership in source package"
            return
          end
          object = nil
          if per_package_locking
            object = spkg
          else
            object = spkg.db_project
          end
          unless object.enabled_for?('lock', nil, nil)
            f = object.flags.find_by_flag_and_status("lock", "disable")
            object.flags.delete(f) if f # remove possible existing disable lock flag
            object.flags.create(:status => "enable", :flag => "lock")
            object.store
          end
        else
          # Creating requests from packages where no maintainer right exists will enforce a maintainer review
          # to avoid that random people can submit versions without talking to the maintainers 
          # projects may skip this by setting OBS:ApprovedRequestSource attributes
          if action.source_package
            spkg = DbPackage.find_by_project_and_name action.source_project, action.source_package
            if spkg and not @http_user.can_modify_package? spkg and not spkg.db_project.find_attribute("OBS", "ApprovedRequestSource") and not spkg.find_attribute("OBS", "ApprovedRequestSource")
              review_packages.push({ :by_project => action.source_project, :by_package => action.source_package })
            end
          else
            sprj = DbProject.find_by_name action.source_project
            if sprj and not @http_user.can_modify_project? sprj and not sprj.find_attribute("OBS", "ApprovedRequestSource")
              review_packages.push({ :by_project => action.source_project })
            end
          end
        end
      end

      # find reviewers in target package
      if tpkg
        reviewers += find_reviewers(tpkg)
        review_groups += find_review_groups(tpkg)
      end
      # project reviewers get added additionaly
      if tprj
        reviewers += find_reviewers(tprj)
        review_groups += find_review_groups(tprj)
      end
    end
    
    # apply reviewers
    reviewers.uniq.each do |r| 
      req.reviews.new :by_user => r.login 
      req.state = :review
    end
    review_groups.uniq.each do |g| 
      req.reviews.new :by_group => g.title
      req.state = :review
    end
    review_packages.uniq.each do |p|
      r = req.reviews.new :by_project => p[:by_project]
      r.by_package = p[:by_package] if p[:by_package]
      req.state = :review
    end

    #
    # create the actual request
    #
    req.save!
    render :text => req.render_xml, :content_type => 'text/xml'
  end

  def command_diff
    valid_http_methods :post

    req = BsRequest.find params[:id]

    diff_text = ""
    action_counter = 0

    if params[:view] == 'xml'
      xml_request = ActiveXML::Base.new("<request id='#{req.id}'/>")
    else
      xml_request = nil
    end

    req.bs_request_actions.each do |action|
      action_diff = ''
      action_counter += 1
      path = nil
      if [:submit, :maintenance_release, :maintenance_incident].include?(action.action_type)
        spkgs = []
        if action.source_package
          spkgs << DbPackage.get_by_project_and_name( action.source_project, action.source_package )
        else
          spkgs = DbProject.get_by_name( action.source_project ).db_packages
        end

        spkgs.each do |spkg|
          target_project = target_package = nil

          if action.target_project
            target_project = action.target_project
            target_package = action.target_package
          end

          # the target is by default the _link target
          # maintenance_release creates new packages instance, but are changing the source only according to the link
          provided_in_other_action=false
          if target_package.nil? or [ :maintenance_release, :maintenance_incident ].include? action.action_type
            data = REXML::Document.new( backend_get("/source/#{URI.escape(action.source_project)}/#{URI.escape(spkg.name)}") )
            e = data.elements["directory/linkinfo"]
            if e
              target_project = e.attributes["project"]
              target_package = e.attributes["package"]
              if target_project == action.source_project
                # a local link, check if the real source change gets also transported in a seperate action
                req.bs_request_actions.each do |a|
                  if action.source_project == a.source_project and e.attributes["package"] == a.source_package and \
                     action.target_project == a.target_project
                    provided_in_other_action=true
                  end
                end
              end
            end
          end

          # maintenance incidents shall show the final result after release
          target_project = action.target_releaseproject if action.target_releaseproject

          # fallback name as last resort
          target_package = action.source_package if target_package.nil?

          if ai = action.bs_request_action_accept_info
            # OBS 2.1 adds acceptinfo on request accept
            path = "/source/%s/%s?cmd=diff" % [CGI.escape(target_project), CGI.escape(target_package)]
            if ai.xsrcmd5
              path += "&rev=" + ai.xsrcmd5
            else
              path += "&rev=" + ai.srcmd5
            end
            if ai.oxsrcmd5
              path += "&orev=" + ai.oxsrcmd5
            elsif ai.osrcmd5
              path += "&orev=" + ai.osrcmd5
            else
              # md5sum of empty package
              path += "&orev=d41d8cd98f00b204e9800998ecf8427e"
            end
          else
            # for requests not yet accepted or accepted with OBS 2.0 and before
            tpkg = linked_tpkg = nil
            if DbPackage.exists_by_project_and_name( target_project, target_package, false )
              tpkg = DbPackage.get_by_project_and_name( target_project, target_package )
            elsif DbPackage.exists_by_project_and_name( target_project, target_package, true )
              tpkg = linked_tpkg = DbPackage.get_by_project_and_name( target_project, target_package )
            else
              DbProject.get_by_name( target_project )
            end

            path = "/source/#{CGI.escape(action.source_project)}/#{CGI.escape(spkg.name)}?cmd=diff&filelimit=10000"
            unless provided_in_other_action
              # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
              # also get sure that the request would not modify the link in the target
              unless action.updatelink
                path += "&expand=1"
              end
            end
            if tpkg
              path += "&oproject=#{CGI.escape(target_project)}&opackage=#{CGI.escape(target_package)}"
              path += "&rev=#{action.source_rev}" if action.source_rev
            else # No target package means diffing the source package against itself.
              if action.source_rev # Use source rev for diffing (if available)
                path += "&orev=0&rev=#{action.source_rev}"
              else # Otherwise generate diff for latest source package revision
                spkg_rev = Directory.find(:project => action.source_project, :package => spkg.name).rev
                path += "&orev=0&rev=#{spkg_rev}"
              end
            end
          end
          # run diff
          path += '&view=xml' if params[:view] == 'xml' # Request unified diff in full XML view
          path += '&withissues=1' if params[:withissues] == '1' || params[:withissues] == 'true' # Include issues
          begin
            action_diff += Suse::Backend.post(path, nil).body
          rescue ActiveXML::Transport::Error => e
            render_error :status => 404, :errorcode => 'diff_failure', :message => "The diff call for #{path} failed" and return
          end
          path = nil # reset
        end
      elsif action.action_type == :delete
        if action.target_package
          path = "/source/#{CGI.escape(action.target_project)}/#{CGI.escape(action.target_package)}"
          path += "?cmd=diff&expand=1&filelimit=0&rev=0"
        else
          #FIXME: Delete requests for whole projects needs project diff supporte in the backend (and api).
          render_error :status => 501, :errorcode => 'project_diff_failure', :message => "Project diff isn't implemented yet" and return
        end
        path += '&view=xml' if params[:view] == 'xml' # Request unified diff in full XML view
        begin
          action_diff += Suse::Backend.post(path, nil).body
        rescue ActiveXML::Transport::Error
          render_error :status => 404, :errorcode => 'diff_failure', :message => "The diff call for #{path} failed" and return
        end
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
    params[:user] = @http_user.login
    required_parameters :id

    req = BsRequest.find params[:id]
    if not @http_user or not @http_user.login
      render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "Action requires authentifacted user."
      return
    end

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and request.body
      params[:comment] = request.body.read
    end

    # We do not support to revert changes from accepted requests (yet)
    if req.state == :accepted
       render_error :status => 403, :errorcode => "post_request_no_permission",
         :message => "change state from an accepted state is not allowed."
       return
    end

    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if [ :accepted, :superseded, :revoked ].include? req.state
       if [ "accepted", "declined", "superseded", "revoked" ].include? params[:newstate]
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "set state to #{params[:newstate]} from a final state is not allowed."
          return
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
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "Request is in review state. You may use the force parameter to ignore this."
          return
       end
    end

    # valid users and groups ?
    if params[:by_user] 
       User.get_by_login(params[:by_user])
    end
    if params[:by_group] 
       Group.get_by_title(params[:by_group])
    end

    # valid project or package ?
    if params[:by_project] and params[:by_package]
      pkg = DbPackage.get_by_project_and_name(params[:by_project], params[:by_package])
    elsif params[:by_project]
      prj = DbProject.get_by_name(params[:by_project])
    end

    # generic permission checks
    permission_granted = false
    if @http_user.is_admin?
      permission_granted = true
    elsif params[:newstate] == "deleted"
      render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "Deletion of a request is only permitted for administrators. Please revoke the request instead."
      return
    elsif params[:cmd] == "addreview" or params[:cmd] == "setincident"
      unless [ :review, :new ].include? req.state
        render_error :status => 403, :errorcode => "add_review_no_permission",
              :message => "The request is not in state new or review"
        return
      end
      # allow request creator to add further reviewers
      permission_granted = true if (req.creator == @http_user.login or req.is_reviewer? @http_user)
    elsif params[:cmd] == "changereviewstate"
      unless req.state == :review or req.state == :new
        render_error :status => 403, :errorcode => "review_change_state_no_permission",
                :message => "The request is neither in state review nor new"
        return
      end
      if params[:by_user]
        unless @http_user.login == params[:by_user]
          render_error :status => 403, :errorcode => "review_change_state_no_permission",
                :message => "review state change is not permitted for #{@http_user.login}"
          return
        end
      end
      if params[:by_group]
        unless @http_user.is_in_group?(params[:by_group])
          render_error :status => 403, :errorcode => "review_change_state_no_permission",
                :message => "review state change for group #{params[:by_group]} is not permitted for #{@http_user.login}"
          return
        end
      end
      if params[:by_project] 
        if params[:by_package]
          unless @http_user.can_modify_package? pkg
            render_error :status => 403, :errorcode => "review_change_state_no_permission",
                  :message => "review state change for package #{params[:by_project]}/#{params[:by_package]} is not permitted for #{@http_user.login}"
            return
          end
        else
          unless @http_user.can_modify_project? prj
            render_error :status => 403, :errorcode => "review_change_state_no_permission",
                  :message => "review state change for project #{params[:by_project]} is not permitted for #{@http_user.login}"
            return
          end
        end
      end
      # 
      permission_granted = true
    elsif req.state != "accepted" and ["new","review","revoked","superseded"].include?(params[:newstate]) and req.creator == @http_user.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state == "declined" and (params[:newstate] == "new" or params[:newstate] == "review") and req.state.who == @http_user.login
      # people who declined a request shall also be able to reopen it
      permission_granted = true
    end

    if params[:newstate] == "superseded" and not params[:superseded_by]
      render_error :status => 403, :errorcode => "post_request_missing_parameter",
               :message => "Supersed a request requires a 'superseded_by' parameter with the request id."
      return
    end

    # permission and validation check for each action inside
    write_permission_in_some_source = false
    write_permission_in_some_target = false

    req.bs_request_actions.each do |action|

      # all action types need a target project in any case for accept
      target_project = DbProject.find_by_name(action.target_project)
      target_package = source_package = nil
      if not target_project and params[:newstate] == "accepted"
        render_error :status => 400, :errorcode => 'not_existing_target',
          :message => "Unable to process project #{action.target_project}; it does not exist."
        return
      end

      if [ :submit, :change_devel, :maintenance_release, :maintenance_incident ].include? action.action_type
        source_package = nil
        if [ "declined", "revoked", "superseded" ].include? params[:newstate]
          # relaxed access checks for getting rid of request
          source_project = DbProject.find_by_name(action.source_project)
        else
          # full read access checks
          source_project = DbProject.get_by_name(action.source_project)
          target_project = DbProject.get_by_name(action.target_project)
          if action.action_type == :change_devel and action.target_package.nil?
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "Target package is missing in request #{req.id} (type #{action.action_type})"
            return
          end
          if action.source_package or action.action_type == :change_devel
            source_package = DbPackage.get_by_project_and_name action.source_project, action.source_package
          end
          # require a local source package
          if [ :change_devel ].include? action.action_type
            unless source_package
              render_error :status => 404, :errorcode => "unknown_package",
                :message => "Local source package is missing for request #{req.id} (type #{action.action_type})"
              return
            end
          end
          # accept also a remote source package
          if source_package.nil? and [ :submit ].include? action.action_type
            unless DbPackage.exists_by_project_and_name( source_project.name, action.source_package, true, true)
              render_error :status => 404, :errorcode => "unknown_package",
                :message => "Source package is missing for request #{req.id} (type #{action.action_type})"
              return
            end
          end
          # maintenance incident target permission checks
          if [ :maintenance_incident ].include? action.action_type
            if params[:cmd] == "setincident"
              if target_project.project_type == "maintenance_incident"
                render_error :status => 404, :errorcode => "target_not_maintenance",
                  :message => "The target project is already an incident, changing is not possible via set_incident"
                return
              end
              unless target_project.project_type.to_s == "maintenance"
                render_error :status => 404, :errorcode => "target_not_maintenance",
                  :message => "The target project is not of type maintenance but #{target_project.project_type}"
                return
              end
              tip = DbProject.get_by_name(action.target_project + ":" + params[:incident])
              if tip.is_locked?
                render_error :status => 403, :errorcode => "project_locked",
                  :message => "The target project is locked"
                return
              end
            else
              unless [ "maintenance", "maintenance_incident" ].include? target_project.project_type.to_s
                render_error :status => 404, :errorcode => "target_not_maintenance_or_incident",
                  :message => "The target project is not of type maintenance or incident but #{target_project.project_type}"
                return
              end
            end
          end
          # maintenance_release accept check
          if [ :maintenance_release ].include? action.action_type and params[:cmd] == "changestate" and params[:newstate] == "accepted"
            # compare with current sources
            if action.source_rev
              # FIXME2.4 we have a directory model
              url = "/source/#{CGI.escape(action.source_project)}/#{CGI.escape(action.source_package)}?expand=1"
              c = backend_get(url)
              data = REXML::Document.new( c )
              unless action.source_rev == data.elements["directory"].attributes["srcmd5"]
                render_error :status => 400, :errorcode => "source_changed",
                  :message => "The current source revision in #{action.source_project}/#{action.source_package} are not on revision #{action.source_rev} anymore."
                return
              end
            end

            # write access check in release targets
            source_project.repositories.each do |repo|
              repo.release_targets.each do |releasetarget|
                unless @http_user.can_modify_project? releasetarget.target_repository.db_project
                  render_error :status => 403, :errorcode => "release_target_no_permission",
                    :message => "Release target project #{releasetarget.target_repository.db_project.name} is not writable by you"
                  return
                end
              end
            end
          end
        end
        if target_project
          if action.target_package
            target_package = target_project.db_packages.find_by_name(action.target_package)
          elsif [ :submit, :change_devel ].include? action.action_type
            # fallback for old requests, new created ones get this one added in any case.
            target_package = target_project.db_packages.find_by_name(action.source_package)
          end
        end

      elsif [ :delete, :add_role, :set_bugowner ].include? action.action_type
        # target must exist
        if params[:newstate] == "accepted"
          if action.target_package
            target_package = target_project.db_packages.find_by_name(action.target_package)
            unless target_package
              render_error :status => 400, :errorcode => 'not_existing_target',
                :message => "Unable to process package #{action.target_project}/#{action.target_package}; it does not exist."
              return
            end
            if action.action_type == :delete
              target_package.can_be_deleted?
            end
          else
            if action.action_type == :delete
              target_project.can_be_deleted?
            end
          end
        end
      else
        render_error :status => 400, :errorcode => "post_request_no_permission",
          :message => "Unknown request type #{params[:newstate]} of request #{req.id} (type #{action.action_type})"
        return
      end

      # general source write permission check (for revoke)
      if ( source_package and @http_user.can_modify_package?(source_package,true) ) or
         ( not source_package and source_project and @http_user.can_modify_project?(source_project,true) )
           write_permission_in_some_source = true
      end
    
      # general write permission check on the target on accept
      write_permission_in_this_action = false
      if target_package 
        if @http_user.can_modify_package? target_package
          write_permission_in_some_target = true
          write_permission_in_this_action = true
        end
      else
        if target_project and @http_user.can_create_package_in? target_project
          write_permission_in_some_target = true
          write_permission_in_this_action = true
        end
      end

      # abort immediatly if we want to write and can't.
      if params[:cmd] == "changestate" and [ "accepted" ].include? params[:newstate] and not write_permission_in_this_action
        msg = "No permission to modify target of request #{req.id} (type #{action.action_type}): project #{action.target_project}"
        msg += ", package #{action.target_package}" if action.target_package
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => msg
        return
      end
    end # end of each action check

    # General permission checks if a write access in any location is enough
    unless permission_granted
      if ["addreview", "setincident"].include? params[:cmd]
        # Is the user involved in any project or package ?
        unless write_permission_in_some_target or write_permission_in_some_source
          render_error :status => 403, :errorcode => "addreview_not_permitted",
            :message => "You have no role in request #{req.id}"
          return
        end
      elsif params[:cmd] == "changestate" 
        if [ "superseded" ].include? params[:newstate]
          # Is the user involved in any project or package ?
          unless write_permission_in_some_target or write_permission_in_some_source
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "You have no role in request #{req.id}"
            return
          end
        elsif [ "accepted" ].include? params[:newstate] 
          # requires write permissions in all targets, this is already handled in each action check
        elsif [ "revoked" ].include? params[:newstate] 
          # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
          unless write_permission_in_some_source
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "No permission to revoke request #{req.id}"
            return
          end
        elsif req.state == :revoked and [ "new" ].include? params[:newstate] 
          unless write_permission_in_some_source
            # at least on one target the permission must be granted on decline
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "No permission to reopen request #{req.id}"
            return
          end
        elsif req.state == :declined and [ "new" ].include? params[:newstate] 
          unless write_permission_in_some_target
            # at least on one target the permission must be granted on decline
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "No permission to reopen request #{req.id}"
            return
          end
        elsif [ "declined" ].include? params[:newstate] 
          unless write_permission_in_some_target
            # at least on one target the permission must be granted on decline
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "No permission to change decline request #{req.id}"
            return
          end
        else
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "No permission to change request #{req.id} state"
          return
        end
      else
        render_error :status => 400, :errorcode => "code_error",
          :message => "PLEASE_REPORT: we lacked to handle this situation in our code !"
        return
      end
    end

    # permission granted for the request at this point

    # special command defining an incident to be merged
    check_for_patchinfo = false
    # all maintenance_incident actions go into the same incident project
    incident_project = nil
    req.bs_request_actions.each do |action|
      if action.action_type == :maintenance_incident
        tprj = DbProject.get_by_name action.target_project

        if params[:cmd] == "setincident"
          # use an existing incident
          if tprj.project_type.to_s == "maintenance"
            tprj = DbProject.get_by_name(action.target_project + ":" + params[:incident])
            action.target_project = tprj.name
            action.save!
          end
        elsif params[:cmd] == "changestate" and params[:newstate] == "accepted"
          # the accept case, create a new incident if needed
          if tprj.project_type.to_s == "maintenance"
            # create incident if it is a maintenance project
            unless incident_project
              incident_project = create_new_maintenance_incident(tprj, nil, req ).db_project
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
          prj = DbProject.get_by_name(action.source_project)
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
    params[:comment] = req.description

    # We have permission to change all requests inside, now execute
    req.bs_request_actions.each do |action|
      # general source update options exists ?
      sourceupdate = action.sourceupdate

      if action.action_type == :set_bugowner
          object = DbProject.find_by_name(action.target_project)
          bugowner = Role.get_by_title("bugowner")
          if action.target_package
             object = object.db_packages.find_by_name(action.target_package)
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
          object = DbProject.find_by_name(action.target_project)
          if action.target_package
             object = object.db_packages.find_by_name(action.target_package)
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
          target_project = DbProject.get_by_name(action.target_project)
          target_package = target_project.db_packages.find_by_name(action.target_package)
          target_package.develpackage = DbPackage.get_by_project_and_name(action.source_project, action.source_package)
          begin
            target_package.resolve_devel_package
            target_package.store
          rescue DbPackage::CycleError => e
            # FIXME: this needs to be checked before, or we have a half submitted request
            render_error :status => 403, :errorcode => "devel_cycle", :message => e.message
            return
          end
      elsif action.action_type == :submit
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => action.source_project,
            :opackage => action.source_package,
            :noservice => 1,
            :requestid => params[:id],
            :comment => params[:comment],
	    :withacceptinfo => 1
          }
          cp_params[:orev] = action.source_rev if action.source_rev
          cp_params[:dontupdatesource] = 1 if sourceupdate == "noupdate"
          unless action.updatelink
            cp_params[:expand] = 1
            cp_params[:keeplink] = 1
          end

          #create package unless it exists already
          target_project = DbProject.get_by_name(action.target_project)
          if action.target_package
            target_package = target_project.db_packages.find_by_name(action.target_package)
          else
            target_package = target_project.db_packages.find_by_name(action.source_package)
          end

          relinkSource=false
          unless target_package
            # check for target project attributes
            initialize_devel_package = target_project.find_attribute( "OBS", "InitializeDevelPackage" )
            # create package in database
            linked_package = target_project.find_package(action.target_package)
            if linked_package
              target_package = Package.new(linked_package.to_axml, :project => action.target_project)
            else
              # FIXME2.4 we have Package model
              answer = Suse::Backend.get("/source/#{URI.escape(action.source_project)}/#{URI.escape(action.source_package)}/_meta")
              target_package = Package.new(answer.body.to_s, :project => action.target_project)
              target_package.remove_all_flags
              target_package.remove_devel_project
              if initialize_devel_package
                target_package.set_devel( :project => action.source_project, :package => action.source_package )
                relinkSource=true
              end
            end
            target_package.remove_all_persons
            target_package.name = action.target_package
            target_package.save

            # check if package was available via project link and create a branch from it in that case
            if linked_package
              Suse::Backend.post "/source/#{CGI.escape(action.target_project)}/#{CGI.escape(action.target_package)}?cmd=branch&noservice=1&oproject=#{CGI.escape(linked_package.db_project.name)}&opackage=#{CGI.escape(linked_package.name)}", nil
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
            h[:user] = @http_user.login
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
          if action.target_package
            package = DbPackage.get_by_project_and_name(action.target_project, action.target_package, true, false)
            package.destroy
            delete_path = "/source/#{action.target_project}/#{action.target_package}"
          else
            project = DbProject.get_by_name(action.target_project)
            project.destroy
            delete_path = "/source/#{action.target_project}"
          end
          h = { :user => @http_user.login, :comment => params[:comment], :requestid => params[:id] }
          delete_path << build_query_from_hash(h, [:user, :comment, :requestid])
          Suse::Backend.delete delete_path

      elsif action.action_type == :maintenance_incident
        # create or merge into incident project
        source = nil
        if action.source_package
          source = DbPackage.get_by_project_and_name(action.source_project, action.source_package)
        else
          source = DbProject.get_by_name(action.source_project)
        end

        incident_project = DbProject.get_by_name(action.target_project)

        # the incident got created before
        merge_into_maintenance_incident(incident_project, source, action.target_releaseproject, req)

        # update action with real target project
        action.target_project = incident_project.name

      elsif action.action_type == :maintenance_release
        pkg = DbPackage.get_by_project_and_name(action.source_project, action.source_package)
#FIXME2.5: support limiters to specified repositories
        release_package(pkg, action.target_project, action.target_package, action.source_rev, nil, nil, acceptTimeStamp, req)
        projectCommit[action.target_project] = action.source_project
      end

      # general source cleanup, used in submit and maintenance_incident actions
      if sourceupdate == "cleanup"
        # cleanup source project
        source_project = DbProject.find_by_name(action.source_project)
        delete_path = nil
        if source_project.db_packages.count == 1 or action.source_package.nil?
          # remove source project, if this is the only package and not the user's home project
          if source_project.name != "home:" + user.login
            source_project.destroy
            delete_path = "/source/#{action.source_project}"
          end
        else
          # just remove one package
          source_package = source_project.db_packages.find_by_name(action.source_package)
          source_package.destroy
          delete_path = "/source/#{action.source_project}/#{action.source_package}"
        end
        del_params = {
          :user => @http_user.login,
          :requestid => params[:id],
          :comment => params[:comment]
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
        :user => @http_user.login,
        :requestid => params[:id],
        :rev => "latest",
        :comment => "Release from project: " + sprj
      }
      commit_path = "/source/#{URI.escape(tprj)}/_project"
      commit_path << build_query_from_hash(commit_params, [:cmd, :user, :comment, :requestid, :rev])
      Suse::Backend.post commit_path, nil
    end

    # create a patchinfo if missing and incident has just been created
    if check_for_patchinfo
      unless DbPackage.find_by_project_and_kind incident_project.name, "patchinfo"
        patchinfo = DbPackage.new(:name => "patchinfo", :title => "Patchinfo", :description => "Collected packages for update")
        incident_project.db_packages << patchinfo
        patchinfo.add_flag("build", "enable", nil, nil)
        patchinfo.add_flag("useforbuild", "disable", nil, nil)
        patchinfo.add_flag("publish", "enable", nil, nil) unless incident_project.flags.find_by_flag_and_status("access", "disable")
        patchinfo.store

        # create patchinfo XML file
        node = Builder::XmlMarkup.new(:indent=>2)
        attrs = { }
        if patchinfo.db_project.project_type.to_s == "maintenance_incident"
          # this is a maintenance incident project, the sub project name is the maintenance ID
          attrs[:incident] = patchinfo.db_project.name.gsub(/.*:/, '')
        end
        xml = node.patchinfo(attrs) do |n|
          node.packager    req.creator
          node.category    "recommended" # update_patchinfo may switch to security
          node.rating      "low"
          node.summary     req.description.split(/\n|\r\n/)[0] # first line only
          node.description req.description
        end
        data =ActiveXML::Base.new(node.target!)
        xml = update_patchinfo( data, patchinfo, true ) # update issues
        p={ :user => @http_user.login, :comment => "generated by request id #{req.id} accept call" }
        patchinfo_path = "/source/#{CGI.escape(patchinfo.db_project.name)}/patchinfo/_patchinfo"
        patchinfo_path << build_query_from_hash(p, [:user, :comment])
        backend_put( patchinfo_path, data.dump_xml )
        patchinfo.sources_changed
      end
    end

    # maintenance_incident request are modifying the request during accept
    req.change_state(params[:newstate], :comment => params[:comment], :superseded_by => params[:superseded_by])
    render_ok
  end
end

