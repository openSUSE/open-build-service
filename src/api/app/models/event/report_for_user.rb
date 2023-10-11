module Event
  class ReportForUser < Report
    self.description = 'Report for a user has been created'
    payload_keys :user_login
  end
end
