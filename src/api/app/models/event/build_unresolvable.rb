module Event
  class BuildUnresolvable < Build
    self.message_bus_routing_key = 'package.build_unresolvable'
    self.description = 'Package build is unresolvable'

    create_jobs :report_to_scm_job

    def state
      'unresolvable'
    end
  end
end
