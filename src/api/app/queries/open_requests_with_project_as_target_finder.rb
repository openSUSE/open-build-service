class OpenRequestsWithProjectAsTargetFinder < OpenRequestsFinder
  def requests_finder
    @relation.where(bs_request_actions: { target_project: @project_name })
  end
end
