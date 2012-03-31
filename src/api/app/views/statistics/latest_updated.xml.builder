
xml.latest_updated do
  @list.each do |item|

    ### item is a package
    if item.instance_of? DbPackage
      xml.package(
        :name => item.name,
        :project => item.db_project.name,
        :updated => item.updated_at.xmlschema
      )
    end

    ### item is a project
    if item.instance_of? DbProject
      xml.project(
        :name => item.name,
        :updated => item.updated_at.xmlschema
      )
    end

  end
end

