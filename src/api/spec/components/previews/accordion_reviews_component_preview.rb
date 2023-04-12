class AccordionReviewsComponentPreview < ViewComponent::Preview
  include FactoryBot::Syntax::Methods

  # Preview at http://HOST:PORT/rails/view_components/accordion_reviews_component/preview
  def preview
    # TODO: revisit the component so we are able to simply instantiate the user instead of using one from DB.
    preview_tester = User.first

    pending_reviews = build_list(:user_review, 3, state: :new, by_user: preview_tester.login, user: preview_tester)
    accepted_reviews = build_list(:user_review, 2, state: :accepted, by_user: preview_tester.login, user: preview_tester)
    declined_review = build_list(:user_review, 1, state: :declined, by_user: preview_tester.login, user: preview_tester)
    render(AccordionReviewsComponent.new(pending_reviews + accepted_reviews + declined_review, :review, can_handle_request: true))
  end
end
