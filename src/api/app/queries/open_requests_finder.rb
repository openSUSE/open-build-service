# Base Class
class OpenRequestsFinder
  def initialize(relation, project_name)
    @relation = relation
    @project_name = project_name
  end

  def call
    BsRequest.where(id: requests_finder.select('bs_requests.id'))
  end

  def requests_finder
    @relation
  end
end
