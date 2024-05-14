RSpec.describe TokenPolicy, type: :policy do
  subject { described_class }

  let(:token_user) { create(:confirmed_user) }
  let(:user_token) { create(:rebuild_token, executor: token_user) }
  let(:group) { create(:group_with_user) }
  let(:other_user) { group.users.first }
  let(:unconfirmed_user) { create(:user, state: 'unconfirmed') }
  let(:token_of_unconfirmed_user) { create(:rebuild_token, executor: unconfirmed_user) }

  # Create and update are permitted when the user and the executor are the same
  permissions :create?, :update?, :destroy? do
    it { is_expected.to permit(token_user, user_token) }
    it { is_expected.not_to permit(other_user, user_token) }
  end

  describe TokenPolicy::Scope do
    describe '#resolve' do
      let!(:scope) { Token }

      context 'when the user is associated to the token' do
        subject { described_class.new(token_user, scope) }

        let!(:token_user) { create(:confirmed_user) }
        let!(:other_user) { create(:confirmed_user) }
        let!(:workflow_token) { create(:workflow_token, executor: token_user) }
        let!(:other_users_workflow_token) { create(:workflow_token, executor: other_user) }
        let!(:shared_workflow_token) { create(:workflow_token, executor: other_user) }

        before do
          token_user.shared_workflow_tokens << shared_workflow_token
        end

        it 'returns the workflow token the token_user created' do
          expect(subject.resolve).to include(workflow_token)
        end

        it 'does not return the workflow token the other_user created' do
          expect(subject.resolve).not_to include(other_users_workflow_token)
        end

        it 'returns the workflow token the token_user shared with other_user' do
          expect(subject.resolve).to include(shared_workflow_token)
        end
      end

      context 'when the group is associated to the token' do
        subject { described_class.new(other_user, scope) }

        let!(:group_shared_workflow_token) { create(:workflow_token, executor: other_user, string: 'group token') }

        before do
          group.shared_workflow_tokens << group_shared_workflow_token
        end

        it 'returns the workflow token associated to the group of other_user' do
          expect(subject.resolve).to include(group_shared_workflow_token)
        end
      end
    end
  end
end
