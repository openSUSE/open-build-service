module Event
  class PackageUpstreamVersionSourceChanged < Base
    self.description = 'Version of the upstream package source has changed'
    self.message_bus_routing_key = 'package.upstream_version_source_changed'
    payload_keys :local_version, :upstream_version, :project, :package
  end
end
