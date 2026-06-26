RSpec.describe BsRequestPolicy, type: :policy do
  subject { BsRequestPolicy }

  permissions :add_reviews? do
    let(:user) { create(:confirmed_user, login: 'iggy') }
    let(:author) { create(:confirmed_user, login: 'foo') }

    shared_examples 'a record in state' do |request_state|
      let(:bs_request) { create(:bs_request_with_submit_action, state: request_state.to_s, creator: author) }

      context 'and the user is a target maintainer' do
        before do
          allow(bs_request).to receive(:target_maintainer?).with(user).and_return(true)
        end

        it { expect(subject).to permit(user, bs_request) }
      end

      context 'and the user is not a target maintainer' do
        before do
          allow(bs_request).to receive(:target_maintainer?).with(user).and_return(false)
        end

        it { expect(subject).not_to permit(user, bs_request) }
      end

      context 'and there are open reviews present for the user' do
        let!(:review) { create(:review, state: 'new', by_user: user.login, bs_request: bs_request) }

        it { expect(subject).to permit(user, bs_request) }
      end

      context 'and there are no open reviews present for the user' do
        let!(:review) { create(:review, state: 'accepted', by_user: user.login, bs_request: bs_request) }

        it { expect(subject).not_to permit(user, bs_request) }
      end

      context 'and the user is the author of the record' do
        it { expect(subject).to permit(author, bs_request) }
      end

      context 'and the user is not the author of the record' do
        it { expect(subject).not_to permit(user, bs_request) }
      end
    end

    context 'for a record in state review or new' do
      it_behaves_like 'a record in state', 'review'
      it_behaves_like 'a record in state', 'new'
    end

    context 'when the record is in any other state then review or new' do
      let(:bs_request) { create(:bs_request_with_submit_action, state: 'declined', creator: author) }
      let!(:review) { create(:review, state: 'new', by_user: user.login, bs_request: bs_request) }

      before do
        allow(bs_request).to receive(:target_maintainer?).with(author).and_return(true)
      end

      it { expect(subject).not_to permit(author, bs_request) }
    end
  end

  permissions :accept_request? do
    let(:user) { create(:confirmed_user, login: 'iggy') }
    let(:author) { create(:confirmed_user, login: 'foo') }
    let(:project) { create(:project, maintainer: user) }

    context 'when the user is not a target maintainer' do
      let(:bs_request) { create(:bs_request_with_submit_action, state: request_state.to_s, creator: author) }

      context 'when the request state is "new"' do
        let(:request_state) { 'new' }

        it { expect(subject).not_to permit(user, bs_request) }
      end

      context 'when the request state is "declined"' do
        let(:request_state) { 'declined' }

        it { expect(subject).not_to permit(user, bs_request) }
      end
    end

    context 'when the user is a target maintainer' do
      let(:bs_request) { create(:bs_request_with_submit_action, state: request_state.to_s, creator: author, target_project: project) }

      context 'when the request state is "new"' do
        let(:request_state) { 'new' }

        it { expect(subject).to permit(user, bs_request) }
      end

      context 'when the request state is "declined"' do
        let(:request_state) { 'declined' }

        it { expect(subject).not_to permit(user, bs_request) }
      end
    end
  end
end
