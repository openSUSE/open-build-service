module Event
  class PackageOutOfDate < Base
    self.description = 'There is a newer version of the package source available upstream'
    payload_keys :local_version, :upstream_version, :project, :package
  end
end
