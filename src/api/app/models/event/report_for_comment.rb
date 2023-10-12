module Event
  class ReportForComment < Report
    self.description = 'Report for a comment has been created'
    payload_keys :commentable_type, :bs_request_number, :bs_request_action_id,
                 :project_name, :package_name
  end
end
