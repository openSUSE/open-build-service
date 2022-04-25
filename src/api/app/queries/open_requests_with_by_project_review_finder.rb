class OpenRequestsWithByProjectReviewFinder < OpenRequestsFinder
  def requests_finder
    @relation.where("reviews.state = 'new' and reviews.by_project = ? ", @project_name)
  end
end
