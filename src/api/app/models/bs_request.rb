class BsRequest < ActiveXML::Base
  default_find_parameter :id

  # override Object#type to get access to the request type attribute
  def type(*args, &block)
    data[:type]
  end

  # override Object#id to get access to the request id attribute
  def id(*args, &block)
    data[:id]
  end

  def creator
    e = self.has_element?(:history) ? self.history('@name="new"') : state
    raise RuntimeError, 'broken request: no state/history named "new"' if e.nil?
    raise RuntimeError, 'broken request: no attribute named "who"' unless e.has_attribute?(:who)
    return e.who
  end

  def initialize(_data)
    super(_data)

    if self.has_element? 'submit' and self.has_attribute? 'type'
      # old style, convert to new style on the fly
      node = self.submit
      node.data.name = 'action'
      node.data['type'] = 'submit'
      delete_attribute 'type'
    end
  end

  def check_create(user)

    self.each_action do |action|
      if action.data["type"] == "delete"
        #check existence of target
        tprj = DbProject.find_by_name action.target.project
        if tprj
          if action.target.has_attribute? 'package'
            tpkg = tprj.db_packages.find_by_name action.target.package
            unless tpkg
	      return "Unknown package  #{action.target.project} / #{action.target.package}"
            end
          end
        else
          unless DbProject.find_remote_project(action.target.project)
	    return "Project is on remote instance, delete not possible  #{action.target.project}"
          end
	  return "Unknown project #{action.target.project}"
        end
      elsif action.data["type"] == "submit" or action.data["type"] == "change_devel"
        #check existence of source
        sprj = DbProject.find_by_name action.source.project
#        unless sprj or DbProject.find_remote_project(action.source.project)
        unless sprj
	  return "Unknown source project #{action.source.project}"
        end

        unless action.data["type"] == "change_devel" and action.source.package.nil?
          # source package is required for submit, but optional for change_devel
          spkg = sprj.db_packages.find_by_name action.source.package
#          unless spkg or DbProject.find_remote_project(action.source.package)
          unless spkg
	    return "Unknown source package #{action.source.package} in project #{action.source.project}"
          end
        end

        # source update checks
        if action.data["type"] == "submit"
          sourceupdate = nil
          if action.has_element? 'options' and action.options.has_element? 'sourceupdate'
             sourceupdate = action.options.sourceupdate.text
          end
          # cleanup implicit home branches, should be done in client with 2.0
          if not sourceupdate and action.has_element? :target
             if "home:#{user.login}:branches:#{action.target.project}" == action.source.project
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
	      return msg
            end
          end
        end

        unless action.data["type"] == "submit" and action.has_element? 'target'
          # target is required for change_devel, but optional for submit
          tprj = DbProject.find_by_name action.target.project
#          unless sprj or DbProject.find_remote_project(action.source.project)
          unless tprj
	    return "Unknown target project #{action.target.project}"
          end
          if action.data["type"] == "change_devel"
            tpkg = tprj.db_packages.find_by_name action.target.package
            unless tpkg
	      return "Unknown target package #{action.target.package}"
            end
          end
        end

        # We only allow submit/change_devel requests from projects where people have write access
        # to avoid that random people can submit versions without talking to the maintainers 
        if spkg
          unless user.can_modify_package? spkg
	    return "No permission for #{user.login} to create request for package '#{spkg.name}' in project '#{sprj.name}'"
          end
        else
          unless user.can_modify_project? sprj
	    return "No permission to create request based on project '#{sprj.name}'"
          end
        end
      else
	return "Request type is unknown " + action.data["type"]
      end
    end

    return nil
  end

  def check_modify_by_user(user, params)
    
    # generic permission check
    permission_granted = false
    if user.is_admin?
      permission_granted = true
    elsif params[:newstate] == "deleted"
      return "Deletion of a request is only permitted for administrators. Please revoke the request instead."
    elsif params[:newstate] == "superseded" and not params[:superseded_by]
      return "Supersed a request requires a 'superseded_by' parameter with the request id."
    elsif (params[:cmd] == "addreview" and req.creator == user.login)
      # allow request creator to add further reviewers
      permission_granted = true
#    elsif (params[:cmd] == "changereviewstate" and params[:by_group] == # FIXME: support groups
#      permission_granted = true
    elsif (params[:cmd] == "changereviewstate" and params[:by_user] == user.login)
      permission_granted = true
    elsif (req.state.name == "new" or req.state.name == "review") and (params[:newstate] == "superseded" or params[:newstate] == "revoked") and req.creator == user.login
      # allow new -> revoked state change to creators of request
      permission_granted = true
    else # check this for changestate (of request) and addreview command
       # do not allow direct switches from accept to decline or vice versa or double actions
       if params[:newstate] == "accepted" or params[:newstate] == "declined" or params[:newstate] == "superseded"
          if req.state.name == "accepted" or req.state.name == "declined" or req.state.name == "superseded"
	    return "Set state to #{params[:newstate]} from accepted, superseded or declined is not allowed."
	  end
       end
       # Do not accept to skip the review, except force argument is given
       if params[:newstate] == "accepted"
          if req.state.name == "review" and not params[:force]
	    return "Request is in review state."
	  end
       end

       # permission check for each request inside
       req.each_action do |action|
         if action.data["type"] == "submit" or action.data["type"] == "change_devel"
           source_project = DbProject.find_by_name(action.source.project)
           target_project = DbProject.find_by_name(action.target.project)
           if target_project.nil?
	     return "Target project is missing for request #{req.id} (type #{action.data['type']})"
	   end
           if action.target.package.nil? and action.data["type"] == "change_devel"
	     return "Target package is missing in request #{req.id} (type #{action.data['type']})"
	   end
           if params[:newstate] != "declined" and params[:newstate] != "revoked"
             if source_project.nil?
	       return "Source project is missing for request #{req.id} (type #{action.data['type']})"
	     else
               source_package = source_project.db_packages.find_by_name(action.source.package)
             end
             if source_package.nil? and params[:newstate] != "revoked"
	       return "Source package is missing for request #{req.id} (type #{action.data['type']})"
	     end
           end
           if action.target.has_attribute? :package
             target_package = target_project.db_packages.find_by_name(action.target.package)
           else
             target_package = target_project.db_packages.find_by_name(action.source.package)
           end
           if ( target_package and user.can_modify_package? target_package ) or
              ( not target_package and user.can_modify_project? target_project )
              permission_granted = true
           elsif source_project and req.state.name == "new" and params[:newstate] == "revoked" 
              # source project owners should be able to revoke submit requests as well
              source_package = source_project.db_packages.find_by_name(action.source.package)
              if ( source_package and user.can_modify_package? source_package ) or
                 ( not source_package and user.can_modify_project? source_project )
                permission_granted = true
              else
		return "No permission to revoke request #{req.id} (type #{action.data['type']})"
	      end
           else
	     return "No permission to change state of request #{req.id} to #{params[:newstate]} (type #{action.data['type']})"
	   end
    
         elsif action.data["type"] == "delete"
           # check permissions for delete
           project = DbProject.find_by_name(action.target.project)
           package = nil
           if action.target.has_attribute? :package
              package = project.db_packages.find_by_name(action.target.package)
           end
           if user.can_modify_project? project or ( package and user.can_modify_package? package )
             permission_granted = true
           else
	     return "No permission to change state of delete request #{req.id} (type #{action.data['type']})"
	   end
         else
	   return "Unknown request type #{params[:newstate]} of request #{req.id} (type #{action.data['type']})"
	 end
      end
    end

    # at this point permissions should be granted, but let's double check
    if permission_granted != true
      return "No permission to change state of request #{req.id} (INTERNAL ERROR, PLEASE REPORT ! )"
    end

    return nil
  end
end
