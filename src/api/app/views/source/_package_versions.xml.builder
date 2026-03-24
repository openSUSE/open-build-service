xml.package(project: @tpkg.project.name, name: @tpkg.name) do
  xml.version(@tpkg.latest_local_version&.version, type: 'local')
  xml.version(@tpkg.latest_upstream_version&.version, type: 'upstream')
end
