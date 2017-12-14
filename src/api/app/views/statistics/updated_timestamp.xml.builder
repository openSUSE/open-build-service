
xml.latest_updated do
  if @package

    xml.package(
      :name => @package.name,
      :project => @package.project.name,
      :updated => @package.updated_at.xmlschema
    )

  elsif @project

    xml.project(
      :name => @project.name,
      :updated => @project.updated_at.xmlschema
    )

  end
end
