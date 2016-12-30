require 'rails_helper'

RSpec.shared_context 'some assigned reviews and some unassigned reviews' do
  let!(:user) { create(:user) }

  let!(:review_assigned1) { create(:review, by_user: user.login) }
  let!(:review_assigned2) { create(:review, by_user: user.login) }
  let!(:review_unassigned1) { create(:review, by_user: user.login) }
  let!(:review_unassigned2) { create(:review, by_user: user.login) }

  let!(:history_element1) do
    create(:history_element_review_assigned, op_object_id: review_assigned1.id, user_id: user.id)
  end
  let!(:history_element2) do
    create(:history_element_review_assigned, op_object_id: review_assigned2.id, user_id: user.id)
  end
  let!(:history_element3) do
    create(:history_element_review_accepted, op_object_id: review_assigned2.id, user_id: user.id)
  end
  let!(:history_element4) do
    create(:history_element_review_accepted, op_object_id: review_unassigned1.id, user_id: user.id)
  end
end

RSpec.describe Review do
  it { should belong_to(:bs_request).touch(true) }

  describe '.assigned' do
    include_context 'some assigned reviews and some unassigned reviews'

    subject { Review.assigned }
    it { is_expected.to match_array([review_assigned1, review_assigned2]) }
  end

  describe '.unassigned' do
    include_context 'some assigned reviews and some unassigned reviews'

    subject { Review.unassigned }
    it { is_expected.to match_array([review_unassigned1, review_unassigned2]) }
  end
end