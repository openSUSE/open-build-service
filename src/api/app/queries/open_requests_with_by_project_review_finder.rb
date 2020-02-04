class OpenRequestsWithByProjectReviewFinder < OpenRequestsFinder
  def initialize(relation, project_name)
    super(relation, project_name)
  end

  def requests_finder
    @relation.where("reviews.state = 'new' and reviews.by_project = ? ", @project_name)
  end
end
