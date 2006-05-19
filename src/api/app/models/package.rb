class Package < ActiveXML::Base
  def parent_project_name
    @init_options[:project]
  end

  def parent_project
    Project.find parent_project_name
  end
end
