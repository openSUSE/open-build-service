# frozen_string_literal: true

RSpec.describe Review do
  let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
  let(:package) { project.packages.first }
  let(:user) { create(:confirmed_user) }
  let(:bs_request) { create(:bs_request_with_submit_action, creator: user) }

  describe 'BsRequest#apply_default_reviewers' do
    before do
      # Mock default reviewers for each action in the request
      bs_request.bs_request_actions.each do |action|
        allow(action).to receive(:default_reviewers).and_return([project, package])
      end
      bs_request.apply_default_reviewers
    end

    it 'sets correct expiration for project reviews (2 months)' do
      project_review = bs_request.reviews.find_by(by_project: project.name, by_package: nil)
      expect(project_review.expires_at).to be_within(1.minute).of(2.months.from_now)
    end

    it 'sets correct expiration for package reviews (7 days)' do
      package_review = bs_request.reviews.find_by(by_project: project.name, by_package: package.name)
      expect(package_review.expires_at).to be_within(1.minute).of(7.days.from_now)
    end
  end

  describe 'Review.expired scope' do
    let!(:expired_review) { create(:review, bs_request: bs_request, by_user: 'user1', state: :new, expires_at: 1.day.ago) }
    let!(:not_expired_review) { create(:review, bs_request: bs_request, by_user: 'user2', state: :new, expires_at: 1.day.from_now) }
    let!(:accepted_expired_review) { create(:review, bs_request: bs_request, by_user: 'user3', state: :accepted, expires_at: 1.day.ago) }

    it 'includes expired reviews in new state' do
      expect(Review.expired).to include(expired_review)
    end

    it 'excludes reviews that are not yet expired' do
      expect(Review.expired).not_to include(not_expired_review)
    end

    it 'excludes expired reviews that are already accepted' do
      expect(Review.expired).not_to include(accepted_expired_review)
    end
  end

  describe 'BsRequest#expire_review' do
    let(:review) { create(:review, bs_request: bs_request, by_user: user.login, state: :new, expires_at: 1.day.ago) }

    it 'accepts the review and adds a comment' do
      bs_request.expire_review(review)
      review.reload
      expect(review.state).to eq(:accepted)
      expect(review.reason).to eq('Automatic acceptance due to expiration')
    end

    it 'updates the request state if all reviews are accepted' do
      bs_request.state = :review
      bs_request.save!

      bs_request.expire_review(review)
      bs_request.reload
      expect(bs_request.state).to eq(:new)
    end
  end
end
