RSpec.describe Token::WorkflowPolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:user_token) { create(:workflow_token, executor: user) }
  let(:other_user) { group.users.first }
  let(:group) { create(:group_with_user) }

  describe '#trigger' do
    context 'user inactive' do
      it_behaves_like 'non-active users cannot trigger a token'
    end

    # As a workflow token is not tied to a package, any user can create one as long as their account is active.
    context 'user active' do
      let(:user) { create(:confirmed_user, login: 'foo') }

      permissions :trigger? do
        it { is_expected.to permit(user, user_token) }
      end
    end
  end

  permissions :create? do
    context 'when the user is the owner of the token' do
      it { is_expected.to permit(user, user_token) }
    end

    context 'when the user belongs to a group which owns the token' do
      let(:group_token) { create(:workflow_token, executor: user) }

      before { group.shared_workflow_tokens << group_token }

      it { is_expected.to permit(other_user, group_token) }
    end

    context 'when the user is not the owner of the token' do
      context 'and the token has not been shared with that user' do
        it { is_expected.not_to permit(other_user, user_token) }
      end

      context 'but the token has been shared with that user' do
        before do
          other_user.shared_workflow_tokens << user_token
        end

        it { is_expected.to permit(other_user, user_token) }
      end

      context "but the token has been shared with that users's group" do
        before do
          group.shared_workflow_tokens << user_token
        end

        it { is_expected.to permit(other_user, user_token) }
      end
    end
  end

  permissions :destroy? do
    context 'when the user is the owner of the token' do
      it { is_expected.to permit(user, user_token) }
    end

    context 'when the user belongs to a group which owns the token' do
      let(:group_token) { create(:workflow_token, executor: user) }

      before { group.shared_workflow_tokens << group_token }

      it { is_expected.to permit(other_user, group_token) }
    end

    context 'when the user does not own the token' do
      it { is_expected.not_to(permit(other_user, user_token)) }
    end
  end
end
