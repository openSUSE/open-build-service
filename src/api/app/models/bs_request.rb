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
end
