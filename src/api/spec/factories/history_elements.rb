FactoryBot.define do
  factory 'history_element' do
    user
    comment { Faker::Lorem.paragraph }

    # Inheriting from HistoryElement::Review

    factory :history_element_review_assigned, class: 'HistoryElement::ReviewAssigned' do
      type { 'HistoryElement::ReviewAssigned' }
    end

    factory :history_element_review_accepted, class: 'HistoryElement::ReviewAccepted' do
      type { 'HistoryElement::ReviewAccepted' }
    end

    factory :history_element_review_declined, class: 'HistoryElement::ReviewDeclined' do
      type { 'HistoryElement::ReviewDeclined' }
    end

    # Inheriting from HistoryElement::Request

    factory :history_element_request_accepted, class: 'HistoryElement::RequestAccepted' do
      op_object_id { create(:bs_request_with_submit_action).id }
      type { 'HistoryElement::RequestAccepted' }
    end

    factory :history_element_request_revoked, class: 'HistoryElement::RequestRevoked' do
      op_object_id { create(:bs_request_with_submit_action).id }
      type { 'HistoryElement::RequestRevoked' }
    end

    factory :history_element_request_review_added_with_review, class: 'HistoryElement::RequestReviewAdded' do
      type { 'HistoryElement::RequestReviewAdded' }

      before(:create) do |history_element|
        bs_request = create(:bs_request_with_submit_action, review_by_user: create(:confirmed_user))
        history_element.update(description_extension: bs_request.reviews.first.id.to_s, op_object_id: bs_request.id)
      end
    end

    factory :history_element_request_review_accepted_with_review_by_group, class: 'HistoryElement::ReviewAccepted' do
      type { 'HistoryElement::ReviewAccepted' }

      before(:create) do |history_element|
        bs_request = create(:bs_request_with_submit_action, review_by_group: create(:group))
        review = bs_request.reviews.first
        review.update(state: :accepted)
        history_element.update(op_object_id: review.id)
      end
    end

    factory :history_element_request_review_accepted_with_review_by_project, class: 'HistoryElement::ReviewAccepted' do
      type { 'HistoryElement::ReviewAccepted' }

      before(:create) do |history_element|
        bs_request = create(:bs_request_with_submit_action, review_by_project: create(:project))
        review = bs_request.reviews.first
        review.update(state: :accepted)
        history_element.update(op_object_id: review.id)
      end
    end

    factory :history_element_request_review_accepted_with_review_by_package, class: 'HistoryElement::ReviewAccepted' do
      type { 'HistoryElement::ReviewAccepted' }

      before(:create) do |history_element|
        bs_request = create(:bs_request_with_submit_action, review_by_package: create(:package))
        review = bs_request.reviews.first
        review.update(state: :accepted)
        history_element.update(op_object_id: review.id)
      end
    end

    factory :history_element_request_review_added_without_review, class: 'HistoryElement::RequestReviewAdded' do
      type { 'HistoryElement::RequestReviewAdded' }
      description_extension { nil }

      before(:create) do |history_element|
        bs_request = create(:bs_request_with_submit_action, review_by_user: create(:confirmed_user))
        history_element.update(op_object_id: bs_request.id)
      end
    end

    factory :history_element_request_superseded, class: 'HistoryElement::RequestSuperseded' do
      type { 'HistoryElement::RequestSuperseded' }

      before(:create) do |history_element|
        superseding_bs_request = create(:bs_request_with_submit_action)
        superseded_bs_request = create(:superseded_bs_request, superseded_by_request: superseding_bs_request)

        history_element.update(description_extension: superseded_bs_request.superseded_by.to_s, op_object_id: superseded_bs_request.id)
      end
    end
  end
end
