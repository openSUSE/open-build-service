class RequestsFinder
  def initialize(relation = BsRequest.includes(:bs_request_actions))
    @relation = relation
  end

  def count_incoming(request_numbers, project_name)
    @relation.where(number: request_numbers).where(bs_request_actions: { target_project: project_name }).count
  end

  def count_outgoing(request_numbers, project_name)
    @relation.where(number: request_numbers).where(bs_request_actions: { source_project: project_name }).count
  end
end
