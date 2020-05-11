FactoryBot.define do
  factory :history_element_review_assigned, class: 'HistoryElement::ReviewAssigned' do
    type { 'HistoryElement::ReviewAssigned' }
  end

  factory :history_element_review_accepted, class: 'HistoryElement::ReviewAccepted' do
    type { 'HistoryElement::ReviewAccepted' }
  end

  factory :history_element_review_declined, class: 'HistoryElement::ReviewDeclined' do
    type { 'HistoryElement::ReviewDeclined' }
  end

  factory :history_element_request_accepted, class: 'HistoryElement::RequestAccepted' do
    type { 'HistoryElement::RequestAccepted' }
  end

  factory :history_element_request_revoked, class: 'HistoryElement::RequestRevoked' do
    type { 'HistoryElement::RequestRevoked' }
  end
end
