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

  describe '#accepted_at' do
    let!(:user) { create(:user) }
    let(:review_state) { :accepted }
    let!(:review) do
      create(
        :review,
        by_user: user.login,
        state: review_state
      )
    end
    let!(:history_element_review_accepted) do
      create(
        :history_element_review_accepted,
        review: review,
        user: user,
        created_at: Faker::Time.forward(1)
      )
    end

    context 'with a review assigned to and assigned to state = accepted' do
      let!(:review2) do
        create(
          :review,
          by_user: user.login,
          review_id: review.id,
          state: :accepted
        )
      end
      let!(:history_element_review_accepted2) do
        create(
          :history_element_review_accepted,
          review: review2,
          user: user,
          created_at: Faker::Time.forward(2)
        )
      end

      subject { review.accepted_at }

      it { is_expected.to eq(history_element_review_accepted2.created_at) }
    end

    context 'with a review assigned to and assigned to state != accepted' do
      let!(:review2) do
        create(
          :review,
          by_user: user.login,
          review_id: review.id,
          updated_at: Faker::Time.forward(2),
          state: :new
        )
      end

      subject { review.accepted_at }

      it { is_expected.to eq(nil) }
    end

    context 'with no reviewed assigned to and state = accepted' do
      subject { review.accepted_at }

      it { is_expected.to eq(history_element_review_accepted.created_at) }
    end

    context 'with no reviewed assigned to and state != accepted' do
      let(:review_state) { :new }

      subject { review.accepted_at }

      it { is_expected.to eq(nil) }
    end
  end

  describe '#validate_not_self_assigned' do
    let!(:user) { create(:user) }
    let!(:review) { create(:review, by_user: user.login) }

    context 'assigned to itself' do
      before { review.review_id = review.id }

      subject! { review.valid? }

      it { expect(review.errors[:review_id].count).to eq(1) }
    end

    context 'assigned to a different review' do
      let!(:review2) { create(:review, by_user: user.login) }

      before { review.review_id = review2.id }

      subject! { review.valid? }

      it { expect(review.errors[:review_id].count).to eq(0) }
    end
  end

  describe '#validate_non_symmetric_assignment' do
    let!(:user) { create(:user) }
    let!(:review) { create(:review, by_user: user.login) }
    let!(:review2) { create(:review, by_user: user.login, review_id: review.id) }

    context 'review1 is assigned to review2 which is already assigned to review1' do
      before { review.review_id = review2.id }

      subject! { review.valid? }

      it { expect(review.errors[:review_id].count).to eq(1) }
    end

    context 'review1 is assigned to review3' do
      let!(:review3) { create(:review, by_user: user.login) }

      before { review.review_id = review3.id }

      subject! { review.valid? }

      it { expect(review.errors[:review_id].count).to eq(0) }
    end
  end
end
