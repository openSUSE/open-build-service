xml.package(name: my_model.name, project: my_model.project.name) do
  xml.title(my_model.title)
  xml.description(my_model.description)
  xml.releasename(my_model.releasename) if my_model.releasename

  xml.devel(project: my_model.develpackage.project.name, package: my_model.develpackage.name) if my_model.develpackage

  my_model.render_relationships(xml)

  FlagHelper.render(my_model, xml)

  xml.url(my_model.url) if my_model.url.present?
  xml.bcntsynctag(my_model.bcntsynctag) if my_model.bcntsynctag.present?
end
