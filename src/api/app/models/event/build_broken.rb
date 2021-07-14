module Event
  class BuildBroken < Build
    self.message_bus_routing_key = 'package.build_broken'
    self.description = 'Package build is broken'

    create_jobs :report_to_scm_job

    def state
      'broken'
    end
  end
end
