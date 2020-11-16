require 'rails_helper'

RSpec.describe UserDailyContribution, type: :service do
  let(:user) { create(:user_with_groups) }
  let(:date) { Time.zone.now.to_date }
  let(:project) { create(:project, name: 'bob_project', maintainer: [user]) }
  let(:package) { create(:package, name: 'bob_package', project: project) }
  let(:another_package) { create(:package) }
  let(:new_bs_request) do
    create(:bs_request_with_submit_action,
           state: :new,
           creator: user,
           target_project: project,
           target_package: package,
           source_package: another_package)
  end
  let(:comment_for_request) do
    create(:comment_request,
           commentable: new_bs_request,
           user: user,
           updated_at: date)
  end

  describe '#call' do
    subject { described_class.new(user, date).call }

    context 'when no contributions exist' do
      it 'returns an empty hash' do
        expect(subject).to include(comments: 0,
                                   commits: [],
                                   requests_created: [],
                                   requests_reviewed: {})
      end
    end

    context 'when comments exist' do
      before do
        comment_for_request
      end

      it 'returns a hash with comments' do
        expect(subject).to include(comments: 1,
                                   commits: [],
                                   requests_created: [1],
                                   requests_reviewed: {})
      end
    end

    context 'when using date times instead of dates' do
      let(:date) { Time.zone.now }

      before do
        comment_for_request
      end

      it 'returns a hash with a request' do
        expect(subject).to include(comments: 1,
                                   commits: [],
                                   requests_created: [1],
                                   requests_reviewed: {})
      end
    end

    context 'when requests exist but no comments exist' do
      before do
        new_bs_request
      end

      it 'returns a hash with a request' do
        expect(subject).to include(comments: 0,
                                   commits: [],
                                   requests_created: [1],
                                   requests_reviewed: {})
      end
    end

    context 'when commits exist' do
      before do
        CommitActivity.create(user: user, date: date, project: project, package: package, count: 1)
      end

      it 'returns a hash with a commit line' do
        expect(subject).to include(comments: 0,
                                   commits: [[project.name, [[package.name, 1]], 1]],
                                   requests_created: [],
                                   requests_reviewed: {})
      end
    end

    context 'when reviews exist' do
      let(:review) do
        create(:review,
               by_user: user.login,
               bs_request: new_bs_request,
               reviewer: user,
               state: :accepted)
      end

      before do
        review
      end

      it 'returns a hash with a commit line' do
        expect(subject).to include(comments: 0,
                                   commits: [],
                                   requests_created: [1],
                                   requests_reviewed: { 1 => 1 })
      end
    end
  end
end
