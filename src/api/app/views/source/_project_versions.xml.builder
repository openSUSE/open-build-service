xml.project(name: @project.name) do
  @packages.each do |pkg|
    xml.package(project: @project.name, name: pkg.name) do
      xml.version(pkg.latest_local_version&.version, type: 'local')
      xml.version(pkg.latest_upstream_version&.version, type: 'upstream')
    end
  end
end
