require Rails.root.join('db/data/20260723180842_prefill_reviews_count_values.rb')

RSpec.describe PrefillReviewsCountValues, type: :migration do
  describe 'up' do
    subject { PrefillReviewsCountValues.new.up }

    let(:bs_request) { create(:bs_request_with_submit_action) }

    before do
      create_list(:user_review, 3, bs_request: bs_request)
      bs_request.update_columns(reviews_count: 0)
    end

    it 'sets reviews_count to the actual number of reviews' do
      expect { subject }.to change { bs_request.reload.reviews_count }.from(0).to(3)
    end
  end
end
