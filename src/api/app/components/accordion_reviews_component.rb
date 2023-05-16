class AccordionReviewsComponent < ApplicationComponent
  def initialize(request_reviews, bs_request)
    super

    @accepted_reviews = request_reviews.select(&:accepted?)
    @accepted_reviews_count = @accepted_reviews.size
    @pending_reviews = request_reviews.select(&:new?)
    @pending_reviews_count = @pending_reviews.size
    @declined_reviews = request_reviews.select(&:declined?)
    @declined_reviews_count = @declined_reviews.size
    @bs_request = bs_request
  end

  def render?
    policy(@bs_request).handle_request? &&
      (@accepted_reviews_count + @pending_reviews_count + @declined_reviews_count).positive? &&
      # Declined is not really a final state, since the request can always be reopened...
      (BsRequest::FINAL_REQUEST_STATES.exclude?(@bs_request.state) || @bs_request.state == :declined)
  end
end
