xml.package(name: my_model.name, project: my_model.project.name) do
  xml.title(my_model.title)
  xml.description(my_model.description)
  xml.releasename(my_model.releasename) if my_model.releasename

  if my_model.develpackage
    xml.devel(project: my_model.develpackage.project.name, package: my_model.develpackage.name)
  end

  my_model.render_relationships(xml)

  FlagHelper.flag_types.each do |flag_name|
    flaglist = my_model.flags.of_type(flag_name)
    xml.send(flag_name) do
      flaglist.each do |flag|
        flag.to_xml(xml)
      end
    end unless flaglist.empty?
  end

  xml.url(my_model.url) unless my_model.url.blank?
  xml.bcntsynctag(my_model.bcntsynctag) unless my_model.bcntsynctag.blank?
end
