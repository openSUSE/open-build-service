# frozen_string_literal: true

class BsRequestAutoAcceptJob < ApplicationJob
  def perform(request_id)
    request = BsRequest.find(request_id)
    request.auto_accept
  end
end
