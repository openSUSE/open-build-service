FactoryBot.define do
  # Inheriting from HistoryElement::Review

  factory :history_element_review_assigned, class: 'HistoryElement::ReviewAssigned' do
    user { create(:user) }
    type { 'HistoryElement::ReviewAssigned' }
  end

  factory :history_element_review_accepted, class: 'HistoryElement::ReviewAccepted' do
    user { create(:user) }
    type { 'HistoryElement::ReviewAccepted' }
  end

  factory :history_element_review_declined, class: 'HistoryElement::ReviewDeclined' do
    user { create(:user) }
    type { 'HistoryElement::ReviewDeclined' }
  end

  # Inheriting from HistoryElement::Request

  factory :history_element_request_accepted, class: 'HistoryElement::RequestAccepted' do
    user { create(:user) }
    op_object_id { create(:bs_request_with_submit_action).id }
    type { 'HistoryElement::RequestAccepted' }
  end

  factory :history_element_request_revoked, class: 'HistoryElement::RequestRevoked' do
    user { create(:user) }
    op_object_id { create(:bs_request_with_submit_action).id }
    type { 'HistoryElement::RequestRevoked' }
  end

  factory :history_element_request_review_added_with_review, class: 'HistoryElement::RequestReviewAdded' do
    user { create(:user) }
    type { 'HistoryElement::RequestReviewAdded' }

    before(:create) do |history_element|
      bs_request = create(:bs_request_with_submit_action, review_by_user: create(:confirmed_user))
      history_element.update(description_extension: bs_request.reviews.first.id.to_s, op_object_id: bs_request.id)
    end
  end

  factory :history_element_request_review_added_without_review, class: 'HistoryElement::RequestReviewAdded' do
    user { create(:user) }
    type { 'HistoryElement::RequestReviewAdded' }
    description_extension { nil }

    before(:create) do |history_element|
      bs_request = create(:bs_request_with_submit_action, review_by_user: create(:confirmed_user))
      history_element.update(op_object_id: bs_request.id)
    end
  end

  factory :history_element_request_superseded, class: 'HistoryElement::RequestSuperseded' do
    user { create(:user) }
    type { 'HistoryElement::RequestSuperseded' }

    before(:create) do |history_element|
      superseding_bs_request = create(:bs_request_with_submit_action)
      superseded_bs_request = create(:superseded_bs_request, superseded_by_request: superseding_bs_request)

      history_element.update(description_extension: superseded_bs_request.superseded_by.to_s, op_object_id: superseded_bs_request.id)
    end
  end
end
