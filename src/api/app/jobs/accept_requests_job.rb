class AcceptRequestsJob < ApplicationJob
  def perform
    BsRequest.to_accept_by_time.each(&:auto_accept)
  end
end
