module Event
  class UpstreamPackageVersionChanged < Base
    self.description = 'Version of the upstream package has changed'
    self.message_bus_routing_key = 'package.upstream_version_changed'

    payload_keys :upstream_version, :project, :package
  end
end
