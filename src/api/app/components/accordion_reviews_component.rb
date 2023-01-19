class AccordionReviewsComponent < ApplicationComponent
  def initialize(request_reviews, request_state, can_handle_request:)
    super

    @can_handle_request = can_handle_request
    @accepted_reviews = request_reviews.select(&:accepted?)
    @accepted_reviews_count = @accepted_reviews.size
    @pending_reviews = request_reviews.select(&:new?)
    @pending_reviews_count = @pending_reviews.size
    @declined_reviews = request_reviews.select(&:declined?)
    @declined_reviews_count = @declined_reviews.size
    @request_state = request_state
  end

  def render?
    @can_handle_request &&
      (@accepted_reviews_count + @pending_reviews_count + @declined_reviews_count).positive? &&
      # Declined is not really a final state, since the request can always be reopened...
      (BsRequest::FINAL_REQUEST_STATES.exclude?(@request_state) || @request_state == :declined)
  end
end
