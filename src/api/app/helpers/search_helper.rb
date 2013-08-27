
module SearchHelper

  include Maintainership

  def search_owner(params, obj)
    params[:attribute] ||= "OBS:OwnerRootProject"
    at = AttribType.find_by_name(params[:attribute])
    unless at
      render_error :status => 404, :errorcode => "unknown_attribute_type",
  		 :message => "Attribute Type #{params[:attribute]} does not exist"
      return
    end
  
    limit  = params[:limit] || 1
  
    projects = []
    if params[:project]
      # default project specified
      projects = [Project.get_by_name(params[:project])]
    else
      # Find all marked projects
      projects = Project.find_by_attribute_type(at)
      if projects.empty?
        render_error :status => 400, :errorcode => "attribute_not_set",
  		   :message => "The attribute type #{params[:attribute]} is not set on any projects. No default projects defined."
        return
      end
    end
  
    # search in each marked project
    owners = []
    projects.each do |project|
  
      attrib = project.attribs.where(attrib_type_id: at.id).first
      filter = ["maintainer","bugowner"]
      devel  = true
      if params[:filter]
        filter=params[:filter].split(",")
      else
        if attrib and v=attrib.values.where(value: "BugownerOnly").exists?
          filter=["bugowner"]
        end
      end
      if params[:devel]
        devel=false if [ "0", "false" ].include? params[:devel]
      else
        if attrib and v=attrib.values.where(value: "DisableDevel").exists?
          devel=false
        end
      end
  
      if obj.nil?
        owners += find_containers_without_definition(project, devel, filter)
      elsif obj.is_a? String
        owners += find_assignees(project, obj, limit.to_i, devel,
                                                filter, (true unless params[:webui_mode].blank?))
      else
        owners += find_containers(project, obj, devel, filter)
      end
  
    end
  
    return owners
  end

end

