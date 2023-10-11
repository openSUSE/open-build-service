module Event
  class ReportForPackage < Report
    self.description = 'Report for a package has been created'
    payload_keys :package_name, :project_name
  end
end
