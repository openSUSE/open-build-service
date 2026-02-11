module Event
  class UpstreamPackageVersionChanged < Base
    self.description = 'Version of the upstream package has changed'
    self.message_bus_routing_key = 'package.upstream_version_changed'
    self.notification_explanation = 'Receive a notification when a new upstream version is available for a package you are involved with.'

    payload_keys :upstream_version, :project, :package

    receiver_roles :maintainer
  end
end
