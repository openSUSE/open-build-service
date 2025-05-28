class OpenRequestsWithProjectAsSourceOrTargetFinder < OpenRequestsFinder
  def requests_finder
    @relation.where('bs_request_actions.source_project = ? or bs_request_actions.target_project = ?', @project_name, @project_name)
  end
end
