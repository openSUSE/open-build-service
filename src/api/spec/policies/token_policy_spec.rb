require 'rails_helper'

RSpec.describe TokenPolicy, type: :policy do
  let(:token_user) { create(:confirmed_user) }
  let(:user_token) { create(:rebuild_token, user: token_user) }
  let(:group) { create(:group_with_user) }
  let(:other_user) { group.users.first }

  let(:workflow_token) { create(:workflow_token, user: token_user) }
  let(:rss_token) { create(:rss_token, user: token_user) }

  subject { described_class }

  permissions :webui_trigger?, :show? do
    it { is_expected.not_to permit(other_user, user_token) }
    it { is_expected.not_to permit(token_user, rss_token) }

    it { is_expected.to permit(token_user, user_token) }
  end

  permissions :show? do
    it { is_expected.to permit(token_user, workflow_token) }
  end

  permissions :webui_trigger? do
    it { is_expected.not_to permit(token_user, workflow_token) }
  end

  describe TokenPolicy::Scope do
    describe '#resolve' do
      let!(:scope) { Token }

      context 'when the user is associated to the token' do
        let!(:token_user) { create(:confirmed_user) }
        let!(:other_user) { create(:confirmed_user) }
        let!(:rss_token) { create(:rss_token, user: token_user) }
        let!(:workflow_token) { create(:workflow_token, user: token_user) }
        let!(:other_users_workflow_token) { create(:workflow_token, user: other_user) }
        let!(:shared_workflow_token) { create(:workflow_token, user: other_user) }

        subject { described_class.new(token_user, scope) }

        before do
          token_user.shared_workflow_tokens << shared_workflow_token
        end

        it 'does not return rss tokens' do
          expect(subject.resolve).not_to include(rss_token)
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
        let!(:group_shared_workflow_token) { create(:workflow_token, user: other_user, string: 'group token') }

        subject { described_class.new(other_user, scope) }

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
