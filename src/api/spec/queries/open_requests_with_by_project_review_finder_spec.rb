RSpec.describe OpenRequestsWithByProjectReviewFinder do
  let(:project) { create(:project, name: 'foo') }
  let(:user) { create(:confirmed_user, login: 'foo') }
  let!(:package) { create(:package, name: 'foo_pack', project: project) }
  let!(:bs_request) { create(:bs_request_with_submit_action, review_by_project: project, creator: user) }

  describe '.call' do
    subject do
      OpenRequestsWithByProjectReviewFinder.new(BsRequest.where(state: %i[new review])
                                                        .joins(:reviews), project.name).call
    end

    it { expect(subject).to contain_exactly(bs_request) }
  end
end
