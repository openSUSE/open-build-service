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
    unless flaglist.empty?
      xml.send(flag_name) do
        flaglist.each do |flag|
          flag.to_xml(xml)
        end
      end
    end
  end

  xml.url(my_model.url) if my_model.url.present?
  xml.bcntsynctag(my_model.bcntsynctag) if my_model.bcntsynctag.present?
end
