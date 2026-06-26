xml.workflow(project: my_model.project.name, managers: my_model.managers_group.title) do
  my_model.staging_projects.each do |staging_project|
    xml.staging_project(name: staging_project.name)
  end
end
