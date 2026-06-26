RSpec.describe ReviewsFinder do
  describe '#completed_by_review' do
    subject { ReviewsFinder.new.completed_by_reviewer(user) }

    let(:user) { create(:confirmed_user) }
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

    context 'when having accepted reviews from the user' do
      let(:review) do
        create(:review,
               by_user: user.login,
               bs_request: new_bs_request,
               reviewer: user,
               state: :accepted)
      end

      before { review }

      it { expect(subject).not_to be_empty }
    end

    context 'when not having accepted reviews from the user' do
      let(:review) do
        create(:review,
               by_user: user.login,
               bs_request: new_bs_request,
               reviewer: user,
               state: :new)
      end

      it { expect(subject).to be_empty }
    end

    context 'when having accepted reviews from another user' do
      let(:another_user) { create(:confirmed_user) }
      let(:review) do
        create(:review,
               by_user: user.login,
               bs_request: new_bs_request,
               reviewer: another_user,
               state: :accepted)
      end

      it { expect(subject).to be_empty }
    end

    context 'when having no reviews' do
      it { expect(subject).to be_empty }
    end
  end
end
