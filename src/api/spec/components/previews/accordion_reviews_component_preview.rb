class AccordionReviewsComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/accordion_reviews_component/preview
  def preview
    pending_reviews = Review.opened.take(3)
    accepted_reviews = Review.accepted.take(2)
    declined_review = Review.declined.take(1)
    render(AccordionReviewsComponent.new(pending_reviews + accepted_reviews + declined_review, :review, can_handle_request: true))
  end
end
