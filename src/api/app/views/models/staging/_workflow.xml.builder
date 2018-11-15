xml.workflow(project: my_model.project.name) do
  my_model.staging_projects.each do |staging_project|
    xml.staging_project(name: staging_project.name)
  end
end
