xml.image_template_projects do
  @projects.each do |image_template|
    xml.image_template_project(name: image_template.name) do
      image_template.packages.each do |package|
        xml.image_template_package do
          xml.name package.name
          xml.title package.title
          xml.description package.description
        end
      end
    end
  end
end
