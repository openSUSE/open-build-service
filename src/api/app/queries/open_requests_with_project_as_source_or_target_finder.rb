class OpenRequestsWithProjectAsSourceOrTargetFinder < OpenRequestsFinder
  def initialize(relation, project_name)
    @relation = relation
    @project_name = project_name
  end

  def requests_finder
    @relation.where('bs_request_actions.source_project = ? or bs_request_actions.target_project = ?', @project_name, @project_name)
  end
end
