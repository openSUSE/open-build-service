
xml.latest_added do
  @list.each do |item|

    ### item is a package
    if item.instance_of? DbPackage
      xml.package(
        :name => item.name,
        :project => item.db_project.name,
        :created => item.created_at.xmlschema
      )
    end

    ### item is a project
    if item.instance_of? DbProject
      xml.project(
        :name => item.name,
        :created => item.created_at.xmlschema
      )
    end

  end
end

