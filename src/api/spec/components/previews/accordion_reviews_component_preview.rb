class AccordionReviewsComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/accordion_reviews_component/preview
  def preview
    pending_reviews = Review.opened.take(3)
    accepted_reviews = Review.accepted.take(2)
    declined_review = Review.declined.take(1)
    request_reviews = accepted_reviews + pending_reviews + declined_review
    bs_request = BsRequest.last || FactoryBot.create(:bs_request_with_submit_action)
    render(AccordionReviewsComponent.new(request_reviews, bs_request))
  end
end
