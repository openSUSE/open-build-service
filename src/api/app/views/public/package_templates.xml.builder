xml.package_template_projects do
  @projects.each do |package_template|
    xml.package_template_project(name: package_template.name, title: package_template.title) do
      package_template.packages.each do |package|
        xml.package_template_package do
          xml.name package.name
          xml.title package.title
        end
      end
    end
  end
end
