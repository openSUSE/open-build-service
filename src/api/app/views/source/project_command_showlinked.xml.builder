xml.collection do
  @project.linked_by_projects.map do |prj|
    xml.project(name: prj.name)
  end
end
