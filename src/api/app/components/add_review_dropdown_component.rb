class AddReviewDropdownComponent < ApplicationComponent
  def initialize(bs_request:, user:, my_open_reviews:, history_elements:)
    super

    @bs_request = bs_request
    @user = user
    @my_open_reviews = my_open_reviews
    @history_elements = history_elements
  end

  def render?
    policy(@bs_request).add_reviews? && @my_open_reviews.present?
  end

  def reviewer_icon_and_text(review:)
    case
    when review.by_package
      tag.i(nil, class: 'fa fa-archive me-2') + "#{review.by_project}/#{review.by_package}"
    when review.by_user
      tag.i(nil, class: 'fa fa-user me-2') + review.by_user.to_s
    when review.by_group
      tag.i(nil, class: 'fa fa-users me-2') + review.by_group.to_s
    when review.by_project
      tag.i(nil, class: 'fa fa-cubes me-2') + review.by_project.to_s
    end
  end

  def reason_when_review_was_requested(review:)
    reason = @history_elements.reverse.find { |history_element| history_element.type == 'HistoryElement::RequestReviewAdded' && history_element.description_extension == review.id.to_s }&.comment

    reason || ''
  end
end
