module Event
  class ReportForRequest < Report
    self.description = 'Report for a request has been created'
    payload_keys :bs_request_number
  end
end
