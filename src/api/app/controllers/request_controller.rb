
include MaintenanceHelper
include ProductHelper

class RequestController < ApplicationController
  #TODO: request schema validation

  # the simple writing action.type instead of action.data.attributes['type'] can not be used, since it is a rails function

  # POST /request?cmd=create
  alias_method :create, :dispatch_command

  # GET /request
  def index
    valid_http_methods :get

    if params[:view] == "collection"
      predicates = []

      # Do not allow a full collection to avoid server load
      if params[:project].blank? and params[:user].blank? and params[:state].blank? and params[:action_type].blank?
       render_error :status => 404, :errorcode => 'require_filter',
         :message => "This call requires at least one filter, either by user, project or package or state or action_type"
       return
      end

      # pending requests are new or in review requests
      if params[:state] == "pending"
        predicates << "(state/@name='new' or state/@name='review')"
      elsif params[:state]
        predicates << "state/@name='#{params[:state]}'"
      end

      # Filter by request type (submit, delete, ...)
      #FIXME/FIXME2.3: This should be params[:type] instead but for whatever reason, all
      # webui controllers already set params[:type] to 'request' (always).
      predicates << "action/@type='#{params[:action_type]}'" if params[:action_type]

      unless params[:project].blank?
        if params[:package].blank?
          str = "action/target/@project='#{params[:project]}'"
          if params[:state] == "pending" or params[:state] == "review"
            str += " or (review[@state='new' and @by_project='#{params[:project]}'] and state/@name='review')"
          end
        else
          str = "action/target/@project='#{params[:project]}' and action/target/@package='#{params[:package]}'"
          if params[:state] == "pending" or params[:state] == "review"
            str += " or (review[@state='new' and @by_project='#{params[:project]}' and @by_package='#{params[:package]}'] and state/@name='review')"
          end
        end
        predicates << str
      end

      if params[:user] # should be set in almost all cases
        # user's own submitted requests
        str = "(state/@who='#{params[:user]}'"
        # requests where the user is reviewer or own requests that are in review by someone else
        str += " or review[@by_user='#{params[:user]}' and @state='new'] or history[@who='#{params[:user]}' and position()=1]" if params[:state] == "pending" or params[:state] == "review"
        # find requests where user is maintainer in target project
        maintained_projects = Array.new
        maintained_projects_hash = Hash.new
        u = User.find_by_login(params[:user])
        u.involved_projects.each do |ip|
          maintained_projects += ["action/target/@project='#{ip.name}'"]
          if params[:state] == "pending" or params[:state] == "review"
            maintained_projects += ["(review[@state='new' and @by_project='#{ip.name}'] and state/@name='review')"]
          end
          maintained_projects_hash[ip.id] = true
        end
        str += " or (" + maintained_projects.join(" or ") + ")" unless maintained_projects.empty?
        ## find request where user is maintainer in target package, except we have to project already
        maintained_packages = Array.new
        u.involved_packages.each do |ip|
          unless maintained_projects_hash.has_key?(ip.db_project_id)
            maintained_packages += ["(action/target/@project='#{ip.db_project.name}' and action/target/@package='#{ip.name}')"]
            if params[:state] == "pending" or params[:state] == "review"
              maintained_packages += ["(review[@state='new' and @by_project='#{ip.db_project.name}' and @by_package='#{ip.name}'] and state/@name='review')"]
            end
          end
        end
        str += " or (" + maintained_packages.join(" or ") + ")" unless maintained_packages.empty?
        str += ")"
        predicates << str
      end

      # Pagination: Discard 'offset' most recent requests (useful with 'count')
      if params[:offset]
        # TODO: Backend XPath engine needs better range support
      end
      # Pagination: Return only 'count' requests
      if params[:count]
        # TODO: Backend XPath engine needs better range support
      end

      pr = predicates.join(" and ")
      logger.debug "running backend query at #{Time.now}"
      c = Suse::Backend.post("/search/request?match=" + CGI.escape(pr), nil)
      render :text => c.body, :content_type => "text/xml"
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
    
    #TODO: allow PUT for non-admins
    unless @http_user.is_admin?
      render_error :status => 403, :errorcode => 'put_request_no_permission',
        :message => "PUT on requests currently requires admin privileges"
      return
    end

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
        obj.package_user_role_relationships.find(:all, :conditions => ["role_id = ?", Role.find_by_title("reviewer").id] ).each do |r|
          reviewers << User.find_by_id(r.bs_user_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_user_role_relationships
      prj.project_user_role_relationships.find(:all, :conditions => ["role_id = ?", Role.find_by_title("reviewer").id] ).each do |r|
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
        obj.package_group_role_relationships.find(:all, :conditions => ["role_id = ?", Role.find_by_title("reviewer").id] ).each do |r|
          review_groups << Group.find_by_id(r.bs_group_id)
        end
      end
      prj = obj.db_project
    else
    end

    # add reviewers of project in any case
    if defined? prj.project_group_role_relationships
      prj.project_group_role_relationships.find(:all, :conditions => ["role_id = ?", Role.find_by_title("reviewer").id] ).each do |r|
        review_groups << Group.find_by_id(r.bs_group_id)
      end
    end
    return review_groups
  end

  # POST /request?cmd=create
  def create_create
    req = BsRequest.new(request.body.read)

    # expand release and submit request targets if not specified
    req.each_action do |action|
      if [ "submit", "maintenance_release" ].include?(action.data.attributes["type"])
        unless action.has_element? 'target'
          packages = Array.new
          if action.source.has_attribute? 'package'
            packages << DbPackage.get_by_project_and_name( action.source.project, action.source.package )
          else
            prj = DbProject.get_by_name action.source.project
            packages = prj.db_packages
          end
          incident_suffix = ""
          if action.data.attributes["type"] == "maintenance_release"
            # The maintenance ID is always the sub project name of the maintenance project
            incident_suffix = "." + action.source.project.gsub(/.*:/, "")
          end

          newPackages = Array.new
          newTargets = Array.new
          packages.each do |pkg|
            # find target via linkinfo or submit to all
            data = REXML::Document.new( backend_get("/source/#{CGI.escape(pkg.db_project.name)}/#{CGI.escape(pkg.name)}") )
            e = data.elements["directory/linkinfo"]
            unless e and DbPackage.exists_by_project_and_name( e.attributes["project"], e.attributes["package"] )
              if action.data.attributes["type"] == "maintenance_release"
                newPackages << pkg.name
                next
              else
                render_error :status => 400, :errorcode => 'unknown_target_package',
                  :message => "target package does not exist"
                return
              end
            end
            newTargets << e.attributes["project"]
            newAction = action.clone
            newAction.add_element 'target' unless newAction.has_element? 'target'
            newAction.source.data.attributes["package"] = pkg.name
            newAction.target.data.attributes["project"] = e.attributes["project"]
            newAction.target.data.attributes["package"] = e.attributes["package"] + incident_suffix
            if action.data.attributes["type"] == "maintenance_release" and not newAction.source.has_attribute? 'rev'
              # maintenance_release needs the binaries, so we always use the current source
              rev=nil
              if e.attributes["xsrcmd5"]
                rev=e.attributes["xsrcmd5"]
              elsif e.attributes["srcmd5"]
                rev=e.attributes["srcmd5"]
              else
                render_error :status => 400, :errorcode => 'broken_source',
                  :message => "Current sources are broken"
                return
              end
              newAction.source.data.attributes["rev"] = rev
            end
            req.add_node newAction.data
          end

          # new packages (eg patchinfos) go to all target projects by default in maintenance requests
          newPackages.each do |pkg|
            newTargets.each do |prj|
              newAction = action.clone
              newAction.add_element 'target' unless newAction.has_element? 'target'
              newAction.source.data.attributes["package"] = pkg
              newAction.target.data.attributes["project"] = prj
              newAction.target.data.attributes["package"] = pkg + incident_suffix
              req.add_node newAction.data
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
        unless User.find_by_login(action.person.name)
          render_error :status => 404, :errorcode => 'unknown_person',
            :message => "Unknown person  #{action.person.data.attributes["name"]}"
          return
        end
        role = action.person.role if action.person.has_attribute? 'role'
      end
      if action.has_element? 'group'
        unless Group.find_by_title(action.group.data.attributes["name"])
          render_error :status => 404, :errorcode => 'unknown_group',
            :message => "Unknown group  #{action.group.data.attributes["name"]}"
          return
        end
        role = action.group.role if action.group.has_attribute? 'role'
      end
      if role
        unless Role.find_by_title(role)
          render_error :status => 404, :errorcode => 'unknown_role',
            :message => "Unknown role  #{role}"
          return
        end
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
          spkg = DbPackage.get_by_project_and_name sprj.name, action.source.package
        end
      end

      if action.has_element?('target') and action.target.has_attribute?('project')
        tprj = DbProject.get_by_name action.target.project
        if action.target.has_attribute? 'package' and not ["submit", "maintenance_release"].include? action.data.attributes["type"]
          tpkg = DbPackage.get_by_project_and_name tprj.name, action.target.package
        end
      end

      # Type specific checks
      if action.data.attributes["type"] == "delete" or action.data.attributes["type"] == "add_role" or action.data.attributes["type"] == "set_bugowner"
        #check existence of target
        unless tprj
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "No target project specified"
          return
        end
        if action.data.attributes["type"] == "add_role"
          unless role
            render_error :status => 404, :errorcode => 'unknown_role',
              :message => "No role specified"
            return
          end
        end
      elsif [ "submit", "change_devel", "maintenance_release", "maintenance_incident" ].include?(action.data.attributes["type"])
        #check existence of source
        unless sprj
          # no support for remote projects yet, it needs special support during accept as well
          render_error :status => 404, :errorcode => 'unknown_project',
            :message => "No source project specified"
          return
        end

        if action.data.attributes["type"] == "submit"
          # source package is required for submit, but optional for change_devel
          unless spkg
            render_error :status => 404, :errorcode => 'unknown_package',
              :message => "No source package specified"
            return
          end

          # validate that the sources are not broken
          begin
            pr = ""
            if action.source.has_attribute?('rev')
              pr = "rev=#{CGI.escape(action.source.rev)}"
            end
            url = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}?expand=1&" + pr
            c = Suse::Backend.get(url)
          rescue ActiveXML::Transport::Error => e
            render_error :status => 400, :errorcode => "expand_error",
              :message => "The source of package #{action.source.project}/#{action.source.package} rev=#{action.source.rev} are broken"
            return
          end
        end

        if action.data.attributes["type"] == "maintenance_incident"
          if spkg
            render_error :status => 400, :errorcode => 'illegal_request',
              :message => "Maintenance requests accept only entire projects as source"
            return
          end
          # find target project via attribute, if not specified
          unless action.has_element? 'target' 
            action.add_element 'target'
          end
          if action.target.has_attribute?(:package)
            render_error :status => 400, :errorcode => 'illegal_request',
              :message => "Maintenance requests accept only projects as target"
            return
          end
          unless action.target.has_attribute?(:project)
            # hardcoded default. frontends can lookup themselfs a different target via attribute search
            at = AttribType.find_by_name("OBS:Maintenance")
            unless at
              render_error :status => 404, :errorcode => 'not_found',
                :message => "Required OBS:Maintenance attribute not found, system not correctly deployed."
              return
            end
            prj = DbProject.find_by_attribute_type( at ).first()
            unless prj
              render_error :status => 404, :errorcode => 'project_not_found',
                :message => "There is no project flagged as maintenance project on server and no target in request defined."
              return
            end
            action.target.data.attributes["project"] = prj.name
          end
        end

        # source update checks
#FIXME2.3: support this also for maintenance requests
        if action.data.attributes["type"] == "submit"
          sourceupdate = nil
          if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
             sourceupdate = action.options.sourceupdate.text
          end
          # cleanup implicit home branches, should be done in client with 2.0
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
          # allow cleanup only, if no devel package reference
          if sourceupdate == 'cleanup'
            unless spkg.develpackages.empty?
              msg = "Unable to delete package #{spkg.name}; following packages use this package as devel package: "
              msg += spkg.develpackages.map {|dp| dp.db_project.name+"/"+dp.name}.join(", ")
              render_error :status => 400, :errorcode => 'develpackage_dependency',
                :message => msg
              return
            end
          end
        end

        if action.data.attributes["type"] == "change_devel"
          unless tpkg
            render_error :status => 404, :errorcode => 'unknown_package',
              :message => "No target package specified"
            return
          end
        end

      else
        render_error :status => 403, :errorcode => "create_unknown_request",
          :message => "Request type is unknown '#{action.data.attributes["type"]}'"
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
          tpkg = tprj.db_packages.find_by_name action.target.package
        elsif action.has_element? 'source' and action.source.has_attribute? 'package'
          tpkg = tprj.db_packages.find_by_name action.source.package
        end
      end
      if action.has_element? 'source'
        # Creating submit request from packages where no maintainer right exists will enforce a maintainer review
        # to avoid that random people can submit versions without talking to the maintainers 
        if action.source.has_attribute? 'package'
          spkg = DbPackage.find_by_project_and_name action.source.project, action.source.package
          if spkg and not @http_user.can_modify_package? spkg
            review_packages.push({ :by_project => action.source.project, :by_package => action.source.package })
          end
        else
          sprj = DbProject.find_by_name action.source.project
          if sprj and not @http_user.can_modify_project? sprj
            review_packages.push({ :by_project => action.source.project })
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
        e.data.attributes["by_user"] = r.login
        e.data.attributes["state"] = "new"
      end
    end
    review_groups.uniq!
    if review_groups.length > 0
      review_groups.each do |g|
        e = req.add_element "review"
        e.data.attributes["by_group"] = g.title
        e.data.attributes["state"] = "new"
      end
    end
    review_packages.uniq!
    if review_packages.length > 0
      review_packages.each do |p|
        e = req.add_element "review"
        e.data.attributes["by_project"] = p[:by_project]
        e.data.attributes["by_package"] = p[:by_package] if p[:by_package]
        e.data.attributes["state"] = "new"
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

    req.each_action do |action|
      if action.data.attributes["type"] == "submit" and action.target.project and action.target.package
        transport = ActiveXML::Config::transport_for(:request)
        path = nil

        if action.has_element? :acceptinfo
          # OBS 2.1 adds acceptinfo on request accept
          path = "/source/%s/%s?cmd=diff" %
               [CGI.escape(action.target.project), CGI.escape(action.target.package)]
          if action.acceptinfo.data.attributes["xsrcmd5"]
            path += "&rev=" + action.acceptinfo.data.attributes["xsrcmd5"]
          else
            path += "&rev=" + action.acceptinfo.data.attributes["srcmd5"]
          end
          if action.acceptinfo.data.attributes["oxsrcmd5"]
            path += "&orev=" + action.acceptinfo.data.attributes["oxsrcmd5"]
          elsif action.acceptinfo.data.attributes["osrcmd5"]
            path += "&orev=" + action.acceptinfo.data.attributes["osrcmd5"]
          else
            # md5sum of empty package
            path += "&orev=d41d8cd98f00b204e9800998ecf8427e"
          end
        else
          # for requests not yet accepted or accepted with OBS 2.0 and before
          spkg = DbPackage.get_by_project_and_name( action.source.project, action.source.package )
          tpkg = linked_tpkg = nil
          if DbPackage.exists_by_project_and_name( action.target.project, action.target.package, follow_project_links = false )
            tpkg = DbPackage.get_by_project_and_name( action.target.project, action.target.package )
          elsif DbPackage.exists_by_project_and_name( action.target.project, action.target.package, follow_project_links = true )
            tpkg = linked_tpkg = DbPackage.get_by_project_and_name( action.target.project, action.target.package )
          else
            tprj = DbProject.get_by_name( action.target.project )
          end

          if tpkg
            path = "/source/%s/%s?oproject=%s&opackage=%s&cmd=diff&expand=1" %
                   [CGI.escape(action.source.project), CGI.escape(action.source.package), CGI.escape(action.target.project), CGI.escape(action.target.package)]
            if action.source.data['rev']
              path += "&rev=#{action.source.rev}"
            end
            if linked_tpkg
              diff_text = "New package instance: " + action.target.project + "/" + action.target.package + " following diff contains diff to package from linked project.\n" + diff_text
            end
          else
            diff_text = "Additional package: " + action.target.project + "/" + action.target.package + "\n" + diff_text
          end
        end

        begin
          diff_text += Suse::Backend.post(path, nil).body if path
        rescue ActiveXML::Transport::Error => e
          render_error :status => 404, :errorcode => 'diff_failure',
                       :message => "The diff call for #{path} failed"
          return
        end

      end
    end

    send_data(diff_text, :type => "text/plain")
  end

  def command_addreview
     command_changestate# :cmd => "addreview",
                       # :by_user => params[:by_user], :by_group => params[:by_group]
  end
  def command_changereviewstate
     command_changestate # :cmd => "changereviewstate", :newstate => params[:newstate], :comment => params[:comment],
                        #:by_user => params[:by_user], :by_group => params[:by_group]
  end
  def command_changestate
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
    params[:user] = @http_user.login

    # transform request body into query parameter 'comment'
    # the query parameter is preferred if both are set
    if params[:comment].blank? and request.body
      params[:comment] = request.body.read
    end

    if req.has_element? 'submit' and req.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = req.submit
      node.data.name = 'action'
      node.data.attributes['type'] = 'submit'
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
    finalStates = [ "accepted", "declined", "superseded", "revoked" ]
    if finalStates.include? req.state.name
       if finalStates.include? params[:newstate]
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "set state to #{params[:newstate]} from a final state is not allowed."
          return
       end
    end

    # enforce state to "review" if going to "new", but review tasks are open
    if params[:newstate] == "new" and req.has_element? 'review'
       req.each_review do |r|
         params[:newstate] = "review" if r.data.attributes['state'] == "new"
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
    if params[:by_user] and User.find_by_login(params[:by_user]).nil?
       render_error :status => 404, :errorcode => "unknown_user",
                :message => "User #{params[:by_user]} is unkown"
       return
    end
    if params[:by_group] and Group.find_by_title(params[:by_group]).nil?
       render_error :status => 404, :errorcode => "unknown_group",
                :message => "Group #{params[:by_group]} is unkown"
       return
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
    elsif params[:cmd] == "addreview" 
      unless [ "review", "new" ].include? req.state.name
        render_error :status => 403, :errorcode => "add_review_no_permission",
              :message => "The request is not in state new or review"
        return
      end
      # allow request creator to add further reviewers
      permission_granted = true if (req.creator == @http_user.login or req.is_reviewer? @http_user)
    elsif params[:cmd] == "changereviewstate"
      unless req.state.name == "review"
        render_error :status => 403, :errorcode => "review_change_state_no_permission",
              :message => "The request is not in state review"
        return
      end
      permission_granted = true if @http_user.is_in_group?(params[:by_group])
      permission_granted = true if params[:by_user] == @http_user.login
      if params[:by_project] 
        if params[:by_package]
          permission_granted = true if @http_user.can_modify_package? pkg
        else
          permission_granted = true if @http_user.can_modify_project? prj
        end
      end
      unless permission_granted
        render_error :status => 403, :errorcode => "review_change_state_no_permission",
              :message => "Changing review state for request #{req.id} not permitted"
        return
      end
    elsif (req.state.name == "new" or req.state.name == "review") and (params[:newstate] == "superseded" or params[:newstate] == "revoked") and req.creator == @http_user.login
      # allow new -> revoked state change to creators of request
      permission_granted = true
    elsif (req.state.name == "revoked" or req.state.name == "declined") and (params[:newstate] == "new" or params[:newstate] == "review") and req.creator == @http_user.login
      # request creator can reopen a request which was declined or revoked
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

      if [ "submit", "change_devel", "maintenance_release", "maintenance_incident" ].include? action.data.attributes["type"]
        source_package = nil
        if [ "declined", "revoked", "superseded" ].include? params[:newstate]
          # relaxed access checks for getting rid of request
          source_project = DbProject.find_by_name(action.source.project)
        else
          # full read access checks
          source_project = DbProject.get_by_name(action.source.project)
          target_project = DbProject.get_by_name(action.target.project)
          if action.data.attributes["type"] == "change_devel" and not action.target.has_attribute? :package
            render_error :status => 403, :errorcode => "post_request_no_permission",
              :message => "Target package is missing in request #{req.id} (type #{action.data.attributes['type']})"
            return
          end
          if action.source.has_attribute? :package
            source_package = DbPackage.get_by_project_and_name source_project.name, action.source.package
          end
          if [ "submit", "change_devel" ].include? action.data.attributes["type"]
            unless source_package
              render_error :status => 404, :errorcode => "unknown_package",
                :message => "Source package is missing for request #{req.id} (type #{action.data.attributes['type']})"
              return
            end
          end
        end
        if target_project
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
          elsif [ "submit", "change_devel" ].include? action.data.attributes["type"]
            # fallback for old requests, new created ones get this one added in any case.
            target_package = target_project.db_packages.find_by_name(action.source.package)
          end
        end
        if source_project and req.state.name == "new" and params[:newstate] == "revoked" 
           # source project owners should be able to revoke submit requests as well
           source_package = source_project.db_packages.find_by_name(action.source.package)
           if ( source_package and not @http_user.can_modify_package? source_package ) or
              ( not source_package and not @http_user.can_modify_project? source_project )
             render_error :status => 403, :errorcode => "post_request_no_permission",
               :message => "No permission to revoke request #{req.id} (type #{action.data.attributes['type']})"
             return
           end
        end

      elsif action.data.attributes["type"] == "delete" or action.data.attributes["type"] == "add_role" or action.data.attributes["type"] == "set_bugowner"
        # target must exist
        if params[:newstate] == "accepted"
          if action.target.has_attribute? :package
            target_package = target_project.db_packages.find_by_name(action.target.package)
            unless target_package
              render_error :status => 400, :errorcode => 'not_existing_target',
                :message => "Unable to process package #{action.target.project}/#{action.target.package}; it does not exist."
              return
            end
          end
        else
          unless target_project
            render_error :status => 400, :errorcode => 'not_existing_target',
              :message => "Unable to process project #{action.target.project}; it does not exist."
            return
          end
        end
      else
        render_error :status => 400, :errorcode => "post_request_no_permission",
          :message => "Unknown request type #{params[:newstate]} of request #{req.id} (type #{action.data.attributes['type']})"
        return
      end

      # general source write permission check (for revoke)
      if ( source_package and @http_user.can_modify_package? source_package ) or
         ( not source_package and source_project and @http_user.can_modify_project? source_project )
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
        msg = "No permission to modify target of request #{req.id} (type #{action.data.attributes['type']}): project #{action.target.project}"
        msg += ", package #{action.target.package}" if action.target.has_attribute? :package
        render_error :status => 403, :errorcode => "post_request_no_permission",
          :message => msg
        return
      end
    end # end of each action check

    # General permission checks if a write access in any location is enough
    unless permission_granted
      if params[:cmd] == "addreview"
        # Is the user involved in any project or package ?
        unless write_permission_in_some_target or write_permission_in_some_source
          render_error :status => 403, :errorcode => "addreview_not_permitted",
            :message => "You have no role in request #{req.id}"
          return
        end
      elsif params[:cmd] == "changestate" and [ "superseded" ].include? params[:newstate]
        # Is the user involved in any project or package ?
        unless write_permission_in_some_target or write_permission_in_some_source
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "You have no role in request #{req.id}"
          return
        end
      elsif params[:cmd] == "changestate" and [ "accepted" ].include? params[:newstate] 
        # requires write permissions in all targets, this is already handled in each action check
      elsif params[:cmd] == "changestate" and [ "revoked" ].include? params[:newstate] 
        # general revoke permission check based on source maintainership. We don't get here if the user is the creator of request
        unless write_permission_in_some_source
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "No permission to revoke request #{req.id}"
          return
        end
      elsif params[:cmd] == "changestate" and [ "declined" ].include? params[:newstate] 
        unless write_permission_in_some_target
          # at least on one target the permission must be granted on decline
          render_error :status => 403, :errorcode => "post_request_no_permission",
            :message => "No permission to change decline request #{req.id} (type #{action.data.attributes['type']})"
          return
        end
      else
        render_error :status => 400, :errorcode => "code_error",
          :message => "PLEASE_REPORT: we lacked to handle this situation in our code !"
        return
      end
    end

    # permission granted for the request at this point

    # All commands are process by the backend. Just the request accept is controlled by the api.
    path = request.path + build_query_from_hash(params, [:cmd, :user, :newstate, :by_user, :by_group, :by_project, :by_package, :superseded_by, :comment])
    unless params[:cmd] == "changestate" and params[:newstate] == "accepted"
      pass_to_backend path
      return
    end

    # We have permission to change all requests inside, now execute
    req.each_action do |action|
      if action.data.attributes["type"] == "set_bugowner"
          object = DbProject.find_by_name(action.target.project)
          bugowner = Role.find_by_title("bugowner")
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
      elsif action.data.attributes["type"] == "add_role"
          object = DbProject.find_by_name(action.target.project)
          if action.target.has_attribute? 'package'
             object = object.db_packages.find_by_name(action.target.package)
          end
          if action.has_element? 'person'
             role = Role.find_by_title(action.person.role)
             object.add_user( action.person.name, role )
          end
          if action.has_element? 'group'
             role = Role.find_by_title(action.group.role)
             object.add_group( action.group.name, role )
          end
          object.store
      elsif action.data.attributes["type"] == "change_devel"
          target_project = DbProject.get_by_name(action.target.project)
          target_package = target_project.db_packages.find_by_name(action.target.package)
          target_package.develpackage = DbPackage.find_by_project_and_name(action.source.project, action.source.package)
          begin
            target_package.resolve_devel_package
            target_package.store
          rescue DbPackage::CycleError => e
            # FIXME: this needs to be checked before, or we have a half submitted request
            render_error :status => 403, :errorcode => "devel_cycle", :message => e.message
            return
          end
      elsif action.data.attributes["type"] == "submit"
          sourceupdate = nil
          if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
            sourceupdate = action.options.sourceupdate.text
          end
          src = action.source
          cp_params = {
            :cmd => "copy",
            :user => @http_user.login,
            :oproject => src.project,
            :opackage => src.package,
            :requestid => params[:id],
            :comment => params[:comment]
          }
          cp_params[:orev] = src.rev if src.has_attribute? :rev
          cp_params[:dontupdatesource] = 1 if sourceupdate == "noupdate"
          unless action.has_element? 'options' and action.options.has_element? 'updatelink' and action.options.updatelink == "true"
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
            source_project = DbProject.find_by_name(action.source.project)
            source_package = source_project.db_packages.find_by_name(action.source.package)
            if linked_package
              target_package = Package.new(linked_package.to_axml, :project => action.target.project)
            else
              target_package = Package.new(source_package.to_axml, :project => action.target.project)
              target_package.remove_all_flags
              target_package.remove_devel_project
              if initialize_devel_package
                target_package.set_devel( :project => source_project.name, :package => source_package.name )
                relinkSource=true
              end
            end
            target_package.remove_all_persons
            target_package.name = action.target.package
            target_package.save

            # check if package was available via project link and create a branch from it in that case
            if linked_package
              r = Suse::Backend.post "/source/#{CGI.escape(action.target.project)}/#{CGI.escape(action.target.package)}?cmd=branch&oproject=#{CGI.escape(linked_package.db_project.name)}&opackage=#{CGI.escape(linked_package.name)}", nil
            end
          end

          cp_path = "/source/#{action.target.project}/#{action.target.package}"
          cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :orev, :expand, :keeplink, :comment, :requestid, :dontupdatesource])
          Suse::Backend.post cp_path, nil

          # cleanup source project
          if relinkSource and not sourceupdate == "noupdate"
            # source package got used as devel package, link it to the target
            # remove it ...
            cp_path = "/source/#{action.source.project}/#{action.source.package}"
            cp_path << build_query_from_hash(cp_params, [:user, :comment])
            Suse::Backend.delete cp_path, nil
            # create again via branch ...
            h = {}
            h[:cmd] = "branch"
            h[:user] = params[:user]
            h[:comment] = "initialized devel package after accepting #{params[:id]}"
            h[:oproject] = action.target.project
            h[:opackage] = action.target.package
            cp_path = "/source/#{CGI.escape(action.source.project)}/#{CGI.escape(action.source.package)}"
            cp_path << build_query_from_hash(h, [:user, :comment, :cmd, :oproject, :opackage])
            Suse::Backend.post cp_path, nil

          elsif sourceupdate == "cleanup"
            # cleanup source project
            source_project = DbProject.find_by_name(action.source.project)
            source_package = source_project.db_packages.find_by_name(action.source.package)
            if source_project.db_packages.count == 1
              # find linking repos
              lreps = Array.new
              source_project.repositories.each do |repo|
                repo.linking_repositories.each do |lrep|
                  lreps << lrep
                end
              end
              if lreps.length > 0
                #replace links to this projects with links to the "deleted" project
                del_repo = DbProject.find_by_name("deleted").repositories[0]
                lreps.each do |link_rep|
                  link_rep.path_elements.find(:all, :include => ["link"]) do |pe|
                    next unless Repository.find_by_id(pe.repository_id).db_project_id == source_project.id
                    pe.link = del_repo
                    pe.save
                    #update backend
                    link_prj = link_rep.db_project
                    logger.info "updating project '#{link_prj.name}'"
                    Suse::Backend.put_source "/source/#{link_prj.name}/_meta", link_prj.to_axml
                  end
                end
              end

              if source_project.name != "home:" + user.login
                # remove source project, if this is the only package and not the user's home project
                source_project.destroy
                Suse::Backend.delete "/source/#{action.source.project}"
              end
            else
              # just remove package
              source_package.destroy
              Suse::Backend.delete "/source/#{action.source.project}/#{action.source.package}"
            end
          end
      elsif action.data.attributes["type"] == "delete"
          if not action.target.has_attribute? :package
            project = DbProject.get_by_name(action.target.project)
            project.destroy
            Suse::Backend.delete "/source/#{action.target.project}"
          else
            DbPackage.transaction do
              package = DbPackage.get_by_project_and_name(action.target.project, action.target.package, use_source=true, follow_project_links=false)
              package.destroy
              Suse::Backend.delete "/source/#{action.target.project}/#{action.target.package}"
            end
          end
      elsif action.data.attributes["type"] == "maintenance_incident"

        # create incident project
        source_project = DbProject.get_by_name(action.source.project)
        target_project = DbProject.get_by_name(action.target.project)
        incident = create_new_maintenance_incident(target_project, source_project, req )

        # update request with real target project
        # FIXME2.3: Discuss this, changing the target on state change is not nice, but avoids an extra element/attribute
        action.target.data["project"] = incident.db_project.name
        req.save

      elsif action.data.attributes["type"] == "maintenance_release"
        pkg = DbPackage.get_by_project_and_name(action.source.project, action.source.package)
        tprj = DbProject.get_by_name(action.target.project)

#FIXME2.3: support limiters to specified repositories
        release_package(pkg, tprj, action.target.package, action.source.rev, req)
      end

      if action.target.has_attribute? :package and action.target.package == "_product"
        update_product_autopackages action.target.project
      end
    end
    pass_to_backend path
  end
end
