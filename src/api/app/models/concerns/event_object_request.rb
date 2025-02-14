module EventObjectRequest
  extend ActiveSupport::Concern

  def event_object
    BsRequest.find_by(number: payload['number'])
  end
end
