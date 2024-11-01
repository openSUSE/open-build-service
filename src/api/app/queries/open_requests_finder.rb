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

  def requests_with_actions(request_numbers)
    @relation.includes(:bs_request_actions).where(number: request_numbers)
  end

  def incoming_requests(request_numbers)
    requests_with_actions(request_numbers).where(bs_request_actions: { target_project: @project_name })
  end

  def outgoing_requests(request_numbers)
    requests_with_actions(request_numbers).where(bs_request_actions: { source_project: @project_name })
  end
end
