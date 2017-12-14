
xml.latest_added do
  if @package

    xml.package(
      :name => @package.name,
      :project => @package.project.name,
      :created => @package.created_at.xmlschema
    )

  elsif @project

    xml.project(
      :name => @project.name,
      :created => @project.created_at.xmlschema
    )

  end
end
