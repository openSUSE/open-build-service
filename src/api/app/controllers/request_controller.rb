require 'base64'

include MaintenanceHelper
include ProductHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # the simple writing action.type instead of action.value('type') can not be used, since it is a rails function

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  #TODO: allow PUT for non-admins
  before_filter :require_admin, :only => [:update]

  # GET /request
  def index
    valid_http_methods :get

    if params[:view] == "collection"
      #FIXME: Move this code into a model so that it can be reused in other controllers
      outer_and = []

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

      # filter for request state(s)
      if states.count > 0
        inner_or = []
        states.each do |s|
          inner_or << "state/@name='#{s}'"
        end
        str = "(" + inner_or.join(" or ") + ")"
        outer_and << str
      end

      # Filter by request type (submit, delete, ...)
      if types.count > 0
        inner_or = []
        types.each do |t|
          inner_or << "action/@type='#{t}'"
        end
        str = "(" + inner_or.join(" or ") + ")"
        outer_and << str
      end

      unless params[:project].blank?
        inner_or = []

        if params[:package].blank?
          if roles.count == 0 or roles.include? "source"
            if params[:subprojects].blank?
              inner_or << "action/source/@project='#{params[:project]}'"
            else
              inner_or << "starts-with(action/source/@project='#{params[:project]}:')"
            end
          end
          if roles.count == 0 or roles.include? "target"
            if params[:subprojects].blank?
              inner_or << "action/target/@project='#{params[:project]}'"
            else
              inner_or << "starts-with(action/target/@project='#{params[:project]}:')"
            end
          end

          if roles.count == 0 or roles.include? "reviewer"
            if states.count == 0 or states.include? "review"
              review_states.each do |r|
                inner_or << "(review[@state='#{r}' and @by_project='#{params[:project]}'])"
              end
            end
          end
        else
          inner_or << "action/source/@project='#{params[:project]}' and action/source/@package='#{params[:package]}'" if roles.count == 0 or roles.include? "source"
          inner_or << "action/target/@project='#{params[:project]}' and action/target/@package='#{params[:package]}'" if roles.count == 0 or roles.include? "target"
          if roles.count == 0 or roles.include? "reviewer"
            if states.count == 0 or states.include? "review"
              review_states.each do |r|
                inner_or << "(review[@state='#{r}' and @by_project='#{params[:project]}' and @by_package='#{params[:package]}'])"
              end
            end
          end
        end

        if inner_or.count > 0
          str = "(" + inner_or.join(" or ") + ")"
          outer_and << str
        end
      end

      if params[:user]
        inner_or = []
        user = User.get_by_login(params[:user])
        # user's own submitted requests
        if roles.count == 0 or roles.include? "creator"
          inner_or << "state/@who='#{user.login}' and not (history)"
          inner_or << "history[@who='#{user.login}' and position()=1]"
        end

        # find requests where user is maintainer in target project
        if roles.count == 0 or roles.include? "maintainer"
          maintained_projects = Array.new
          user.involved_projects.each do |ip|
            inner_or << ["action/target/@project='#{ip.name}'"]
          end

          ## find request where user is maintainer in target package, except we have to project already
          maintained_packages = Array.new
          user.involved_packages.each do |ip|
            inner_or << ["(action/target/@project='#{ip.db_project.name}' and action/target/@package='#{ip.name}')"]
          end
        end

        if roles.count == 0 or roles.include? "reviewer"
          review_states.each do |r|
            # requests where the user is reviewer or own requests that are in review by someone else
            inner_or << "review[@by_user='#{user.login}' and @state='#{r}']"
            # include all groups of user
            user.groups.each do |g|
              inner_or << "review[@by_group='#{g.title}' and @state='#{r}']"
            end

            # find requests where user is maintainer in target project
            maintained_projects = Array.new
            user.involved_projects.each do |ip|
              inner_or << ["(review[@state='#{r}' and @by_project='#{ip.name}'] and state/@name='review')"]
            end

            ## find request where user is maintainer in target package, except we have to project already
            maintained_packages = Array.new
            user.involved_packages.each do |ip|
              inner_or << ["(review[@state='#{r}' and @by_project='#{ip.db_project.name}' and @by_package='#{ip.name}'] and state/@name='review')"]
            end
          end
        end

        unless inner_or.empty?
          str = "(" + inner_or.join(" or ") + ")"
          outer_and << str
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

      match = outer_and.join(" and ")
      if match.empty?
        # Initial cornercase, when a user doesn't yet have a home project.Avoid
        # a useless roundtrip that would only cause the backend to mourn.
        render :text => '<collection matches="0"></collection>', :content_type => 'text/xml'
      elsif inner_or.empty? and params[:user] and states == ['new'] and roles == ['maintainer']
        # FIXME: Ugly but currently unresovable hack:
        # User has no involved projects/packages leading to an empty 'inner_or', which itself leads
        # to a match "(state/@name='new')" for combination of parameters of this elsif clause.
        # TODO: Can be removed if we always create a home project for users.
        render :text => '<collection matches="0"></collection>', :content_type => 'text/xml'
      else
        logger.debug "running backend query at #{Time.now}"
        c = Suse::Backend.post("/search/request?match=" + CGI.escape(match), nil)
        render :text => c.body, :content_type => "text/xml"
      end
    else
      # directory list of all requests. not very usefull but for backward compatibility...
      # OBS3: make this more usefull
      pass_to_backend
    end
  end

  # GET /request/:id
  def show
    valid_http_methods :get
    # ACL(show) TODO: check this leaks no information that is prevented by ACL
    # parse and rewrite the request to latest format

    data = Suse::Backend.get("/request/#{CGI.escape params[:id]}").body
    req = BsRequest.new(data)

    send_data(req.dump_xml, :type => "text/xml")
  end

  # POST /request/:id? :cmd :newstate
  alias_method :command, :dispatch_command

  # PUT /request/:id
  def update
    params[:user] = @http_user.login if @http_user

    path = request.path
    path << build_query_from_hash(params, [:user])
    pass_to_backend path
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
        obj.package_user_role_relationships.find(:all, :conditions => ["role_id = ?", Role.get_by_title("reviewer").id] ).each do |r|
          reviewers << User.find_by_id(r.bs_user_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_user_role_relationships
      prj.project_user_role_relationships.find(:all, :conditions => ["role_id = ?", Role.get_by_title("reviewer").id] ).each do |r|
        reviewers << User.find_by_id(r.bs_user_id)
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
        obj.package_group_role_relationships.find(:all, :conditions => ["role_id = ?", Role.get_by_title("reviewer").id] ).each do |r|
          review_groups << Group.find_by_id(r.bs_group_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_group_role_relationships
      prj.project_group_role_relationships.find(:all, :conditions => ["role_id = ?", Role.get_by_title("reviewer").id] ).each do |r|
        review_groups << Group.find_by_id(r.bs_group_id)
      end
    end
    return review_groups
  end

  # POST /request?cmd=create
  def create_create
    req = BsRequest.new(request.body.read)

    # refuse request creation for anonymous users
    if @http_user == http_anonymous_user
      render_error :status => 401, :errorcode => 'anonymous_user',
        :message => "Anonymous user is not allowed to create requests"
      return
    end

    per_package_locking = nil

    # expand release and submit request targets if not specified
    req.each_action do |action|
      if [ "maintenance_incident" ].include?(action.value("type"))
        # find maintenance project
        maintenanceProject = nil
        if action.has_element? 'target' and action.target.has_attribute?(:project)
          maintenanceProject = DbProject.get_by_name action.target.project
        else
          # hardcoded default. frontends can lookup themselfs a different target via attribute search
          at = AttribType.find_by_name("OBS:MaintenanceProject")
          unless at
            render_error :status => 404, :errorcode => 'not_found',
              :message => "Required OBS:Maintenance attribute not found, system not correctly deployed."
            return
          end
          maintenanceProject = DbProject.find_by_attribute_type( at ).first()
          unless maintenanceProject
            render_error :status => 400, :errorcode => 'project_not_found',
              :message => "There is no project flagged as maintenance project on server and no target in request defined."
            return
          end
          action.add_element 'target'
          action.target.set_attribute("project", maintenanceProject.name)
        end
        unless maintenanceProject.project_type == "maintenance" or maintenanceProject.project_type == "maintenance_incident"
          render_error :status => 400, :errorcode => 'no_maintenance_project',
            :message => "Maintenance incident requests have to go to projects of type maintenance or maintenance_incident"
          return
        end
      end

      if [ "submit", "maintenance_release", "maintenance_incident" ].include?(action.value("type"))
        unless action.has_element? 'target' and action.target.has_attribute? 'package'
          packages = Array.new
          if action.source.has_attribute? 'package'
            packages << DbPackage.get_by_project_and_name( action.source.project, action.source.package )
            per_package_locking = 1
          else
            prj = DbProject.get_by_name action.source.project
            packages = prj.db_packages
          end
          incident_suffix = ""
          if action.value("type") == "maintenance_release"
            # The maintenance ID is always the sub project name of the maintenance project
            incident_suffix = "." + action.source.project.gsub(/.*:/, "")
          end

          found_patchinfo = nil
          newPackages = Array.new
          newTargets = Array.new
          packages.each do |pkg|
            # find target via linkinfo or submit to all.
            # FIXME: this is currently handling local project links for packages with multiple spec files. 
            #        This can be removed when we handle this as shadow packages in the backend.
            tprj = pkg.db_project.name
            tpkg = ltpkg = pkg.name
            rev=nil
            if action.source.has_attribute? 'rev'
              rev = action.source.rev.to_s
            end
            data = nil
            missing_ok_link=false
            suffix = ""
            while tprj == pkg.db_project.name
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
            if action.value("type") == "maintenance_incident"

              unless pkg.db_package_kinds.find_by_kind 'patchinfo'
                if action.target.has_attribute? "releaseproject"
                  releaseproject = DbProject.get_by_name action.target.releaseproject
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
                unless releaseproject.project_type == "maintenance_release"
                  render_error :status => 400, :errorcode => 'no_maintenance_release_target',
                    :message => "Maintenance incident request contains release target project #{releaseproject.name} with invalid type #{releaseproject.project_type} for package #{pkg.name}"
                  return
                end
              end
            end

            # do not allow release requests without binaries
            if action.value("type") == "maintenance_release" and data and params["ignore_build_state"].nil?
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
              unless e and DbPackage.exists_by_project_and_name( tprj, tpkg, follow_project_links=true, allow_remote_packages=false)
                if action.value("type") == "maintenance_release"
                  newPackages << pkg
                  pkg.db_project.repositories.each do |repo|
                    repo.release_targets.each do |rt|
                      newTargets << rt.target_repository.db_project.name
                    end
                  end
                  next
                elsif action.value("type") != "maintenance_incident"
                  render_error :status => 400, :errorcode => 'unknown_target_package',
                    :message => "target package does not exist"
                  return
                end
              end
            end
            # is this package source going to a project which is specified as release target ?
            if action.value("type") == "maintenance_release"
              found = nil
              pkg.db_project.repositories.each do |repo|
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
            newAction = ActiveXML::XMLNode.new(action.dump_xml)
            newAction.add_element 'target' unless newAction.has_element? 'target'
            newAction.source.set_attribute("package", pkg.name)
            if action.value("type") == 'maintenance_incident'
              newAction.target.set_attribute("releaseproject", releaseproject.name ) if releaseproject
            else
              newAction.target.set_attribute("project", tprj )
              newAction.target.set_attribute("package", tpkg + incident_suffix)
            end
            newAction.source.set_attribute("rev", rev) if rev
            req.add_node newAction.dump_xml
          end
          if action.value("type") == "maintenance_release" and found_patchinfo.nil? and params["ignore_build_state"].nil?
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
              newAction = ActiveXML::XMLNode.new(action.dump_xml)
              newAction.add_element 'target' unless newAction.has_element? 'target'
              newAction.source.set_attribute("package", pkg.name)
              unless action.value("type") == 'maintenance_incident'
                newAction.target.set_attribute("project", p)
                newAction.target.set_attribute("package", pkg.name + incident_suffix) unless action.value("type") == 'maintenance_incident'
              end
              req.add_node newAction.dump_xml
            end
          end

          req.delete_element action
        end
      end
    end

    # permission checks
    req.each_action do |action|
      # find objects if specified or report error
      role=nil
      sprj=nil
      spkg=nil
      tprj=nil
      tpkg=nil
      if action.has_element? 'person'
        # validate user object
        User.get_by_login(action.person.name)
        role = action.person.role if action.person.has_attribute? 'role'
      end
      if action.has_element? 'group'
        # validate group object
        Group.get_by_title(action.group.value("name"))
        role = action.group.role if action.group.has_attribute? 'role'
      end
      if role
        # validate role object
        Role.get_by_title(role)
      end
      if action.has_element?('source') and action.source.has_attribute?('project')
        sprj = DbProject.get_by_name action.source.project
        unless sprj
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "Unknown source project #{action.source.project}"
          return
        end
        unless sprj.class == DbProject
          render_error :status => 400, :errorcode => 'not_supported',
            :message => "Source project #{action.source.project} is not a local project. This is not supported yet."
          return
        end
        if action.source.has_attribute? 'package'
          spkg = DbPackage.get_by_project_and_name(action.source.project, action.source.package, follow_project_links=true, allow_remote_packages=true)
        end
      end

      if action.has_element?('target') and action.target.has_attribute?('project')
        tprj = DbProject.get_by_name action.target.project
        if tprj.class == DbProject and tprj.project_type == "maintenance_release" and action.value('type') == 'submit'
          render_error :status => 400, :errorcode => 'submit_request_rejected',
            :message => "The target project #{action.target.project} is a maintenance release project, a submit action is not possible, please use the maintenance workflow instead."
          return
        end
        if tprj.class == DbProject and (a = tprj.find_attribute("OBS", "RejectRequests") and a.values.first)
          render_error :status => 403, :errorcode => 'request_rejected',
            :message => "The target project #{action.target.project} is not accepting requests because: #{a.values.first.value.to_s}"
          return
        end
        if action.target.has_attribute? 'package' 
          if DbPackage.exists_by_project_and_name(action.target.project, action.target.package) or ["delete", "change_devel", "add_role", "set_bugowner"].include? action.value("type")
            tpkg = DbPackage.get_by_project_and_name action.target.project, action.target.package
          end
          
          if tpkg && (a = tpkg.find_attribute("OBS", "RejectRequests") and a.values.first)
            render_error :status => 403, :errorcode => 'request_rejected',
              :message => "The target package #{action.target.project} / #{action.target.package} is not accepting requests because: #{a.values.first.value.to_s}"
            return
          end
        end
      end

      # Type specific checks
      if action.value("type") == "delete" or action.value("type") == "add_role" or action.value("type") == "set_bugowner"
        #check existence of target
        unless tprj
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "No target project specified"
          return
        end
        if action.value("type") == "add_role"
          unless role
            render_error :status => 404, :errorcode => 'unknown_role',
              :message => "No role specified"
            return
          end
        end
      elsif [ "submit", "change_devel", "maintenance_release", "maintenance_incident" ].include?(action.value("type"))
        #check existence of source
        unless sprj
          # no support for remote projects yet, it needs special support during accept as well
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "No source project specified"
          return
        end

        if [ "submit", "maintenance_incident", "maintenance_release" ].include? action.value("type")
          # validate that the sources are not broken
          begin
            pr = ""
            if action.source.has_attribute?('rev')
              pr = "&rev=#{CGI.escape(action.source.rev)}"
            end
            url = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}?expand=1" + pr
            c = backend_get(url)
            unless action.source.has_attribute?('rev') or params[:addrevision].blank?
              data = REXML::Document.new( c )
              action.source.set_attribute("rev", data.elements["directory"].attributes["srcmd5"])
            end
          rescue
            render_error :status => 400, :errorcode => "expand_error",
              :message => "The source of package #{action.source.project}/#{action.source.package} rev=#{action.source.rev} are broken"
            return
          end
        end

        if action.value("type") == "maintenance_incident"
          if action.target.has_attribute?(:package)
            render_error :status => 400, :errorcode => 'illegal_request',
              :message => "Maintenance requests accept only projects as target"
            return
          end
          # validate project type
          prj = DbProject.get_by_name(action.target.project)
          unless [ "maintenance", "maintenance_incident" ].include? prj.project_type
            render_error :status => 400, :errorcode => "incident_has_no_maintenance_project",
              :message => "incident projects shall only create below maintenance projects"
            return
          end
        end

        if action.value("type") == "maintenance_release"
          # get sure that the releasetarget definition exists or we release without binaries
          prj = DbProject.get_by_name(action.source.project)
          prj.repositories.each do |repo|
            unless repo.release_targets.size > 0
              render_error :status => 400, :errorcode => "repository_without_releasetarget",
                :message => "Release target definition is missing in #{prj.name} / #{repo.name}"
              return
            end
            unless repo.architectures.size > 0
              render_error :status => 400, :errorcode => "repository_without_architecture",
                :message => "Repository has no architecture #{prj.name} / #{repo.name}"
              return
            end
            repo.release_targets.each do |rt|
              unless repo.architectures.first == rt.target_repository.architectures.first
                render_error :status => 400, :errorcode => "architecture_order_missmatch",
                  :message => "Repository and releasetarget have not the same architecture on first position: #{prj.name} / #{repo.name}"
                return
              end
            end
          end

          # check for open release requests with same target, the binaries can't get merged automatically
          # either exact target package match or with same prefix (when using the incident extension)

          # patchinfos don't get a link, all others should not conflict with any other
          answer = Suse::Backend.get "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}"
          xml = REXML::Document.new(answer.body.to_s)
          if xml.elements["/directory/entry/@name='_patchinfo'"]
            predicate = "(state/@name='new' or state/@name='review') and action/target/@project='#{action.target.project}' and action/target/@package='#{action.target.package}'"
          else
            tpkgprefix = action.target.package.gsub(/\.[^\.]*$/, '')
            predicate = "(state/@name='new' or state/@name='review') and action/target/@project='#{action.target.project}' and (action/target/@package='#{action.target.package}' or starts-with(action/target/@package,'#{tpkgprefix}.'))"
          end

          # run search
          collection = Suse::Backend.post("/search/request?match=#{CGI.escape(predicate)}", nil).body
          rqs = collection.scan(/request id\="(\d+)"/).flatten
          if rqs.size > 0
             render_error :status => 400, :errorcode => "open_release_requests",
               :message => "The following open requests have the same target #{action.target.project} / #{tpkgprefix}: " + rqs.join(', ')
             return
          end
        end

        # source update checks
        sourceupdate = nil
        if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
           sourceupdate = action.options.sourceupdate.text
        end
        if ['submit', 'maintenance_incident'].include?(action.value("type"))
          # cleanup implicit home branches. FIXME3.0: remove this, the clients should do this automatically meanwhile
          if not sourceupdate and action.has_element?(:target) and action.target.has_attribute?(:project)
             if "home:#{@http_user.login}:branches:#{action.target.project}" == action.source.project
               if not action.has_element? 'options'
                 action.add_element 'options'
               end
               sourceupdate = 'cleanup'
               e = action.options.add_element 'sourceupdate'
               e.text = sourceupdate
             end
          end
        end
        # allow cleanup only, if no devel package reference
        if sourceupdate == 'cleanup'
          if spkg 
            spkg.can_be_deleted?
          end
        end

        if action.value("type") == "change_devel"
          unless tpkg
            render_error :status => 404, :errorcode => 'unknown_package',
              :message => "No target package specified"
            return
          end
        end

      else
        render_error :status => 403, :errorcode => "create_unknown_request",
          :message => "Request type is unknown '#{action.value("type")}'"
        return
      end
    end

    #
    # Find out about defined reviewers in target
    #
    # check targets for defined default reviewers
    reviewers = []
    review_groups = []
    review_packages = []

    req.each_action do |action|
      tprj = nil
      tpkg = nil

      if action.has_element?('target') and action.target.has_attribute?('project')
        tprj = DbProject.find_by_name action.target.project
        if action.target.has_attribute? 'package'
          if action.value("type") == "maintenance_release"
            # use orignal/stripped name and also GA projects for maintenance packages
            tpkg = tprj.find_package action.target.package.gsub(/\.[^\.]*$/, '')
          else
            # just the direct affected target
            tpkg = tprj.db_packages.find_by_name action.target.package
          end
        else
          if action.has_element? 'source' and action.source.has_attribute? 'package'
            tpkg = tprj.db_packages.find_by_name action.source.package
          end
        end
      end
      if action.has_element? 'source'
        # if the user is not a maintainer if current devel package, the current maintainer gets added as reviewer of this request
        if action.value("type") == "change_devel" and tpkg.develpackage and not @http_user.can_modify_package?(tpkg.develpackage, 1)
          review_packages.push({ :by_project => tpkg.develpackage.db_project.name, :by_package => tpkg.develpackage.name })
        end

        if action.value("type") == "maintenance_release"
          # creating release requests is also locking the source package, therefore we require write access there.
          spkg = DbPackage.find_by_project_and_name action.source.project, action.source.package
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
          if action.source.has_attribute? 'package'
            spkg = DbPackage.find_by_project_and_name action.source.project, action.source.package
            if spkg and not @http_user.can_modify_package? spkg and not spkg.db_project.find_attribute("OBS", "ApprovedRequestSource") and not spkg.find_attribute("OBS", "ApprovedRequestSource")
              review_packages.push({ :by_project => action.source.project, :by_package => action.source.package })
            end
          else
            sprj = DbProject.find_by_name action.source.project
            if sprj and not @http_user.can_modify_project? sprj and not sprj.find_attribute("OBS", "ApprovedRequestSource")
              review_packages.push({ :by_project => action.source.project })
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
    reviewers.uniq!
    if reviewers.length > 0
      reviewers.each do |r|
        e = req.add_element "review"
        e.set_attribute "by_user", r.login
        e.set_attribute "state", "new"
      end
    end
    review_groups.uniq!
    if review_groups.length > 0
      review_groups.each do |g|
        e = req.add_element "review"
        e.set_attribute "by_group", g.title
        e.set_attribute "state", "new"
      end
    end
    review_packages.uniq!
    if review_packages.length > 0
      review_packages.each do |p|
        e = req.add_element "review"
        e.set_attribute "by_project", p[:by_project]
        e.set_attribute("by_package", p[:by_package]) if p[:by_package]
        e.set_attribute "state", "new"
      end
    end

    #
    # create the actual request
    #
    params[:user] = @http_user.login if @http_user
    path = request.path
    path << build_query_from_hash(params, [:cmd, :user, :comment])
    begin
      response = backend_post( path, req.dump_xml )
    rescue ActiveXML::Transport::Error => e
      render_error :status => 400, :errorcode => "backend_error",
        :message => e.message
      return
    end
    send_data( response, :disposition => "inline" )
  end

  def command_diff
    valid_http_methods :post

    data = Suse::Backend.get("/request/#{CGI.escape params[:id]}").body
    req = BsRequest.new(data)

    diff_text = ""
    action_counter = 0

    req.each_action do |action|
      action_diff = ''
      action_counter += 1
      path = nil
      if ['submit', 'maintenance_release', 'maintenance_incident'].include?(action.value('type'))
        spkgs = []
        if action.source.has_attribute? :package
          spkgs << DbPackage.get_by_project_and_name( action.source.project, action.source.package )
        else
          spkgs = DbProject.get_by_name( action.source.project ).db_packages
        end

        spkgs.each do |spkg|
          target_project = target_package = nil

          if action.has_element? :target
            target_project = action.target.project
            target_package = action.target.package if action.target.has_attribute? :package
          end

          # the target is by default the _link target
          # maintenance_release creates new packages instance, but are changing the source only according to the link
          provided_in_other_action=false
          if target_package.nil? or [ "maintenance_release", "maintenance_incident" ].include? action.value('type')
            data = REXML::Document.new( backend_get("/source/#{URI.escape(action.source.project)}/#{URI.escape(spkg.name)}") )
            e = data.elements["directory/linkinfo"]
            if e
              target_project = e.attributes["project"]
              target_package = e.attributes["package"]
              if target_project == action.source.project
                # a local link, check if the real source change gets also transported in a seperate action
                req.each_action do |a|
                  if action.source.project == a.source.project and e.attributes["package"] == a.source.package and \
                     action.target.project == a.target.project
                    provided_in_other_action=true
                  end
                end
              end
            end
          end

          # maintenance incidents shall show the final result after release
          target_project = action.target.releaseproject if action.target.has_attribute? :releaseproject

          # fallback name as last resort
          target_package = action.source.package if target_package.nil?

          if action.has_element? :acceptinfo
            # OBS 2.1 adds acceptinfo on request accept
            path = "/source/%s/%s?cmd=diff" % [CGI.escape(target_project), CGI.escape(target_package)]
            if action.acceptinfo.value("xsrcmd5")
              path += "&rev=" + action.acceptinfo.value("xsrcmd5")
            else
              path += "&rev=" + action.acceptinfo.value("srcmd5")
            end
            if action.acceptinfo.value("oxsrcmd5")
              path += "&orev=" + action.acceptinfo.value("oxsrcmd5")
            elsif action.acceptinfo.value("osrcmd5")
              path += "&orev=" + action.acceptinfo.value("osrcmd5")
            else
              # md5sum of empty package
              path += "&orev=d41d8cd98f00b204e9800998ecf8427e"
            end
          else
            # for requests not yet accepted or accepted with OBS 2.0 and before
            tpkg = linked_tpkg = nil
            if DbPackage.exists_by_project_and_name( target_project, target_package, follow_project_links = false )
              tpkg = DbPackage.get_by_project_and_name( target_project, target_package )
            elsif DbPackage.exists_by_project_and_name( target_project, target_package, follow_project_links = true )
              tpkg = linked_tpkg = DbPackage.get_by_project_and_name( target_project, target_package )
            else
              tprj = DbProject.get_by_name( target_project )
            end

            path = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(spkg.name)}?cmd=diff&filelimit=10000"
            unless provided_in_other_action
              # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
              path += "&expand=1"
            end
            if tpkg
              path += "&oproject=#{CGI.escape(target_project)}&opackage=#{CGI.escape(target_package)}"
              path += "&rev=#{action.source.rev}" if action.source.value('rev')
            else # No target package means diffing the source package against itself.
              if action.source.value('rev') # Use source rev for diffing (if available)
                path += "&orev=0&rev=#{action.source.rev}"
              else # Otherwise generate diff for latest source package revision
                spkg_rev = Directory.find(:project => action.source.project, :package => spkg.name).rev
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
      elsif action.value('type') == 'delete'
        if action.target.has_attribute? :package
          path = "/source/#{CGI.escape(action.target.project)}/#{CGI.escape(action.target.package)}"
          path += "?cmd=diff&expand=1&filelimit=0&rev=0"
        else
          #FIXME: Delete requests for whole projects needs project diff supporte in the backend (and api).
          render_error :status => 501, :errorcode => 'project_diff_failure', :message => "Project diff isn't implemented yet" and return
        end
        path += '&view=xml' if params[:view] == 'xml' # Request unified diff in full XML view
        begin
          action_diff += Suse::Backend.post(path, nil).body
        rescue ActiveXML::Transport::Error => e
          render_error :status => 404, :errorcode => 'diff_failure', :message => "The diff call for #{path} failed" and return
        end
      end
      if params[:view] == 'xml'
        # Inject backend-provided XML diff into action XML:
        diff_text += action.dump_xml()[0..-10] + action_diff + "</action>\n"
      else
        diff_text += action_diff
      end
    end

    if params[:view] == 'xml'
      # Wrap diff text into <request> tag as it may contain multiple <action> tags
      diff_text = "<request id=\"#{req.value('id')}\" actions=\"#{action_counter}\">\n  #{diff_text}</request>"
      send_data(diff_text, :type => "text/xml")
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
    if params[:id].nil? or params[:id].to_i == 0
      render_error :status => 404, :message => "Request ID is not a number", :errorcode => "no_such_request"
      return
    end
    req = BsRequest.find params[:id]
    if req.nil?
      render_error :status => 404, :message => "No such request", :errorcode => "no_such_request"
      return
    end
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

    if req.has_element? 'submit' and req.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = req.submit
      node.element_name = 'action'
      node.set_attribute('type', 'submit')
      req.delete_attribute('type')
    end

    # We do not support to revert changes from accepted requests (yet)
    if req.state.name == "accepted"
       render_error :status => 403, :errorcode => "post_request_no_permission",
         :message => "change state from an accepted state is not allowed."
       return
    end

    # do not allow direct switches from a final state to another one to avoid races and double actions.
    # request needs to get reopened first.
    if [ "accepted", "superseded", "revoked" ].include? req.state.name
       if [ "accepted", "declined", "superseded", "revoked" ].include? params[:newstate]
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "set state to #{params[:newstate]} from a final state is not allowed."
          return
       end
    end

    # enforce state to "review" if going to "new", when review tasks are open
    if params[:cmd] == "changestate"
       if params[:newstate] == "new" and req.has_element? 'review'
          req.each_review do |r|
            params[:newstate] = "review" if r.value('state') == "new"
          end
       end
    end

    # Do not accept to skip the review, except force argument is given
    if params[:newstate] == "accepted"
       if params[:cmd] == "changestate" and req.state.name == "review" and not params[:force]
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
      unless [ "review", "new" ].include? req.state.name
        render_error :status => 403, :errorcode => "add_review_no_permission",
              :message => "The request is not in state new or review"
        return
      end
      # allow request creator to add further reviewers
      permission_granted = true if (req.creator == @http_user.login or req.is_reviewer? @http_user)
    elsif params[:cmd] == "changereviewstate"
      unless req.state.name == "review" or req.state.name == "new"
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
    elsif req.state.name != "accepted" and ["new","review","revoked","superseded"].include?(params[:newstate]) and req.creator == @http_user.login
      # request creator can reopen, revoke or supersede a request which was declined
      permission_granted = true
    elsif req.state.name == "declined" and (params[:newstate] == "new" or params[:newstate] == "review") and req.state.who == @http_user.login
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

    req.each_action do |action|

      # all action types need a target project in any case for accept
      target_project = DbProject.find_by_name(action.target.project)
      target_package = source_package = nil
      if not target_project and params[:newstate] == "accepted"
        render_error :status => 400, :errorcode => 'not_existing_target',
          :message => "Unable to process project #{action.target.project}; it does not exist."
        return
      end

      if [ "submit", "change_devel", "maintenance_release", "maintenance_incident" ].include? action.value("type")
        source_package = nil
        if [ "declined", "revoked", "superseded" ].include? params[:newstate]
          # relaxed access checks for getting rid of request
          source_project = DbProject.find_by_name(action.source.project)
        else
          # full read access checks
          source_project = DbProject.get_by_name(action.source.project)
          target_project = DbProject.get_by_name(action.target.project)
          if action.value("type") == "change_devel" and not action.target.has_attribute? :package
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "Target package is missing in request #{req.id} (type #{action.value('type')})"
            return
          end
          if action.source.has_attribute? :package or action.value("type") == "change_devel"
            source_package = DbPackage.get_by_project_and_name source_project.name, action.source.package
          end
          # require a local source package
          if [ "change_devel" ].include? action.value("type")
            unless source_package
              render_error :status => 404, :errorcode => "unknown_package",
                :message => "Local source package is missing for request #{req.id} (type #{action.value('type')})"
              return
            end
          end
          # accept also a remote source package
          if source_package.nil? and [ "submit" ].include? action.value("type")
            unless DbPackage.exists_by_project_and_name( source_project.name, action.source.package, follow_project_links=true, allow_remote_packages=true)
              render_error :status => 404, :errorcode => "unknown_package",
                :message => "Source package is missing for request #{req.id} (type #{action.value('type')})"
              return
            end
          end
          # maintenance incident target permission checks
          if [ "maintenance_incident" ].include? action.value("type")
            if params[:cmd] == "setincident"
              unless target_project.project_type == "maintenance"
                render_error :status => 404, :errorcode => "target_not_maintenance",
                  :message => "The target project is not of type maintenance but #{target_project.project_type}"
                return
              end
              tip = DbProject.get_by_name(action.target.project + ":" + params[:incident])
              if tip.is_locked?
                render_error :status => 403, :errorcode => "project_locked",
                  :message => "The target project is locked"
                return
              end
            else
              unless [ "maintenance", "maintenance_incident" ].include? target_project.project_type
                render_error :status => 404, :errorcode => "target_not_maintenance_or_incident",
                  :message => "The target project is not of type maintenance or incident but #{target_project.project_type}"
                return
              end
            end
          end
          # maintenance_release accept check
          if [ "maintenance_release" ].include? action.value("type") and params[:cmd] == "changestate" and params[:newstate] == "accepted"
            # compare with current sources
            if action.source.has_attribute?('rev')
              url = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}?expand=1"
              c = backend_get(url)
              data = REXML::Document.new( c )
              unless action.source.rev == data.elements["directory"].attributes["srcmd5"]
                render_error :status => 400, :errorcode => "source_changed",
                  :message => "The current source revision in #{action.source.project}/#{action.source.package} are not on revision #{action.source.rev} anymore."
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
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
          elsif [ "submit", "change_devel" ].include? action.value("type")
            # fallback for old requests, new created ones get this one added in any case.
            target_package = target_project.db_packages.find_by_name(action.source.package)
          end
        end

      elsif [ "delete", "add_role", "set_bugowner" ].include? action.value("type")
        # target must exist
        if params[:newstate] == "accepted"
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
            unless target_package
              render_error :status => 400, :errorcode => 'not_existing_target',
                :message => "Unable to process package #{action.target.project}/#{action.target.package}; it does not exist."
              return
            end
            if action.value("type") == "delete"
              target_package.can_be_deleted?
            end
          else
            if action.value("type") == "delete"
              target_project.can_be_deleted?
            end
          end
        end
      else
        render_error :status => 400, :errorcode => "post_request_no_permission",
          :message => "Unknown request type #{params[:newstate]} of request #{req.id} (type #{action.value('type')})"
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
        msg = "No permission to modify target of request #{req.id} (type #{action.value('type')}): project #{action.target.project}"
        msg += ", package #{action.target.package}" if action.target.has_attribute? :package
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
        elsif req.state.name == "revoked" and [ "new" ].include? params[:newstate] 
          unless write_permission_in_some_source
            # at least on one target the permission must be granted on decline
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "No permission to reopen request #{req.id}"
            return
          end
        elsif req.state.name == "declined" and [ "new" ].include? params[:newstate] 
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
    store_request=false
    req.each_action do |action|
      if action.value("type") == "maintenance_incident"
        tprj = DbProject.get_by_name action.target.project

        if params[:cmd] == "setincident"
          # use an existing incident
          if tprj.project_type == "maintenance"
            tprj = DbProject.get_by_name(action.target.project + ":" + params[:incident])
            action.target.set_attribute("project", tprj.name)
          end
        elsif params[:cmd] == "changestate" and params[:newstate] == "accepted"
          # the accept case, create a new incident if needed
          if tprj.project_type == "maintenance"
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
            action.target.set_attribute("project", incident_project.name)
            store_request=true
          end
        end
      elsif action.value("type") == "maintenance_release"
        if params[:cmd] == "changestate" and params[:newstate] == "revoked"
          # unlock incident project in the soft way
          prj = DbProject.get_by_name(action.source.project)
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
      req.save
      render_ok
      return
    end

    # All commands are process by the backend. Just the request accept is controlled by the api.
    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate, :by_user, :by_group, :by_project, :by_package, :superseded_by, :comment])
    unless params[:cmd] == "changestate" and params[:newstate] == "accepted"
      # switch state in backend
      pass_to_backend path
      return
    end

    # have a unique time stamp for release
    acceptTimeStamp = Time.now.utc.strftime "%Y-%m-%d %H:%M:%S"
    projectCommit = {}

    # use the request description as comments for history
    params[:comment] = req.value(:description)

    # We have permission to change all requests inside, now execute
    req.each_action do |action|
      # general source update options exists ?
      sourceupdate = nil
      if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
        sourceupdate = action.options.sourceupdate.text
      end

      if action.value("type") == "set_bugowner"
          object = DbProject.find_by_name(action.target.project)
          bugowner = Role.get_by_title("bugowner")
          if action.target.has_attribute? 'package'
             object = object.db_packages.find_by_name(action.target.package)
              PackageUserRoleRelationship.find(:all, :conditions => ["db_package_id = ? AND role_id = ?", object, bugowner]).each do |r|
                r.destroy
             end
          else
              ProjectUserRoleRelationship.find(:all, :conditions => ["db_project_id = ? AND role_id = ?", object, bugowner]).each do |r|
                r.destroy
             end
          end
          object.add_user( action.person.name, bugowner )
          object.store
      elsif action.value("type") == "add_role"
          object = DbProject.find_by_name(action.target.project)
          if action.target.has_attribute? 'package'
             object = object.db_packages.find_by_name(action.target.package)
          end
          if action.has_element? 'person'
             role = Role.get_by_title(action.person.role)
             object.add_user( action.person.name, role )
          end
          if action.has_element? 'group'
             role = Role.get_by_title(action.group.role)
             object.add_group( action.group.name, role )
          end
          object.store
      elsif action.value("type") == "change_devel"
          target_project = DbProject.get_by_name(action.target.project)
          target_package = target_project.db_packages.find_by_name(action.target.package)
          target_package.develpackage = DbPackage.get_by_project_and_name(action.source.project, action.source.package)
          begin
            target_package.resolve_devel_package
            target_package.store
          rescue DbPackage::CycleError => e
            # FIXME: this needs to be checked before, or we have a half submitted request
            render_error :status => 403, :errorcode => "devel_cycle", :message => e.message
            return
          end
      elsif action.value("type") == "submit"
          src = action.source
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => src.value(:project),
            :opackage => src.value(:package),
            :noservice => "1",
            :requestid => params[:id],
            :comment => params[:comment]
          }
          cp_params[:orev] = src.value(:rev) if src.has_attribute? :rev
          cp_params[:dontupdatesource] = 1 if sourceupdate == "noupdate"
          unless action.has_element? 'options' and action.options.value(:updatelink) == "true"
            cp_params[:expand] = 1
            cp_params[:keeplink] = 1
          end

          #create package unless it exists already
          target_project = DbProject.get_by_name(action.target.project)
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
          else
            target_package = target_project.db_packages.find_by_name(action.source.package)
          end

          relinkSource=false
          unless target_package
            # check for target project attributes
            initialize_devel_package = target_project.find_attribute( "OBS", "InitializeDevelPackage" )
            # create package in database
            linked_package = target_project.find_package(action.target.package)
            if linked_package
              target_package = Package.new(linked_package.to_axml, :project => action.target.project)
            else
              answer = Suse::Backend.get("/source/#{URI.escape(action.source.project)}/#{URI.escape(action.source.package)}/_meta")
              target_package = Package.new(answer.body.to_s, :project => action.target.project)
              target_package.remove_all_flags
              target_package.remove_devel_project
              if initialize_devel_package
                target_package.set_devel( :project => action.source.project, :package => action.source.package )
                relinkSource=true
              end
            end
            target_package.remove_all_persons
            target_package.name = action.target.package
            target_package.save

            # check if package was available via project link and create a branch from it in that case
            if linked_package
              r = Suse::Backend.post "/source/#{CGI.escape(action.target.project)}/#{CGI.escape(action.target.package)}?cmd=branch&noservice=1&oproject=#{CGI.escape(linked_package.db_project.name)}&opackage=#{CGI.escape(linked_package.name)}", nil
            end
          end

          cp_path = "/source/#{action.target.project}/#{action.target.package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :keeplink, :comment, :requestid, :dontupdatesource, :noservice])
          Suse::Backend.post cp_path, nil
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
            h[:oproject] = action.target.project
            h[:opackage] = action.target.package
            cp_path = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}"
            cp_path << build_query_from_hash(h, [:user, :comment, :cmd, :oproject, :opackage, :requestid, :keepcontent])
            Suse::Backend.post cp_path, nil
          end

      elsif action.value("type") == "delete"
          if action.target.has_attribute? :package
            package = DbPackage.get_by_project_and_name(action.target.project, action.target.package, use_source=true, follow_project_links=false)
            package.destroy
            delete_path = "/source/#{action.target.project}/#{action.target.package}"
          else
            project = DbProject.get_by_name(action.target.project)
            project.destroy
            delete_path = "/source/#{action.target.project}"
          end
          h = { :user => @http_user.login, :comment => params[:comment], :requestid => params[:id] }
          delete_path << build_query_from_hash(h, [:user, :comment, :requestid])
          Suse::Backend.delete delete_path

      elsif action.value("type") == "maintenance_incident"
        # create or merge into incident project
        source = nil
        if action.source.has_attribute? :package
          source = DbPackage.get_by_project_and_name(action.source.project, action.source.package)
        else
          source = DbProject.get_by_name(action.source.project)
        end

        incident_project = DbProject.get_by_name(action.target.project)

        # the incident got created before
        merge_into_maintenance_incident(incident_project, source, action.target.releaseproject, req)

        # update action with real target project
        action.target.set_attribute("project", incident_project.name)
        store_request=true

      elsif action.value("type") == "maintenance_release"
        pkg = DbPackage.get_by_project_and_name(action.source.project, action.source.package)
#FIXME2.5: support limiters to specified repositories
        release_package(pkg, action.target.project, action.target.package, action.source.rev, nil, nil, acceptTimeStamp, req)
        projectCommit[action.target.project] = action.source.project
      end

      # general source cleanup, used in submit and maintenance_incident actions
      if sourceupdate == "cleanup"
        # cleanup source project
        source_project = DbProject.find_by_name(action.source.project)
        delete_path = nil
        if source_project.db_packages.count == 1 or not action.source.has_attribute?(:package)
          # remove source project, if this is the only package and not the user's home project
          if source_project.name != "home:" + user.login
            source_project.destroy
            delete_path = "/source/#{action.source.project}"
          end
        else
          # just remove one package
          source_package = source_project.db_packages.find_by_name(action.source.package)
          source_package.destroy
          delete_path = "/source/#{action.source.project}/#{action.source.package}"
        end
        del_params = {
          :user => @http_user.login,
          :requestid => params[:id],
          :comment => params[:comment]
        }
        delete_path << build_query_from_hash(del_params, [:user, :comment, :requestid])
        Suse::Backend.delete delete_path
      end

      if action.target.has_attribute? :package and action.target.package == "_product"
        update_product_autopackages action.target.project
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
        xml = node.patchinfo() do |n|
          node.packager    req.creator
          node.category    "recommended" # update_patchinfo may switch to security
          node.rating      "low"
          if req.description
            node.summary     req.description.text.split(/\n|\r\n/)[0] # first line only
            node.description req.description.text
          end
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
    req.save if store_request
    pass_to_backend path
  end
end

