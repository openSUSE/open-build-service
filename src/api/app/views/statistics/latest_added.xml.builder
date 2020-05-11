
xml.latest_added do
  @list.each do |item|
    ### item is a package
    if item.instance_of? Package
      xml.package(
        name: item.name,
        project: item.project.name,
        created: item.created_at.xmlschema
      )
    end

    ### item is a project
    next unless item.instance_of? Project
    xml.project(
      name: item.name,
      created: item.created_at.xmlschema
    )
  end
end
