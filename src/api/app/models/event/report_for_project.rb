module Event
  class ReportForProject < Report
    self.description = 'Report for a project has been created'
    payload_keys :project_name
  end
end
