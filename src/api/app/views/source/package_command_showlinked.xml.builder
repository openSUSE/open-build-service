xml.collection do
  @package.find_linking_packages.map do |pkg|
    xml.package(name: pkg.name, project: pkg.project.name)
  end
end
