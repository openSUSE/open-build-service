require 'rails_helper'

RSpec.describe Webui::Users::Tokens::GroupsController do
  let(:token_group) { create(:group_with_user) }
  let(:other_group) { create(:group) }
  let(:workflow_token) { create(:workflow_token) }
  let(:token_user) { token_group.users.first }

  before do
    Flipper.enable(:trigger_workflow, token_user)
    login token_user
    workflow_token.groups_shared_among << token_group
  end

  describe '#create' do
    render_views

    context 'when the group does not own the token yet' do
      subject! do
        post :create, params: { groupid: other_group, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.groups_shared_among).to match_array([token_group, other_group]) }
    end

    context 'when the group owns the token already' do
      before do
        workflow_token.groups_shared_among << other_group
      end

      subject! do
        post :create, params: { groupid: other_group, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.groups_shared_among).to match_array([token_group, other_group]) }
    end

    context 'someone else tries to own the token' do
      let(:third_user) { create(:confirmed_user) }

      before { login third_user }

      subject! do
        post :create, params: { groupid: other_group, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:success]).to be_nil }
      it { expect(workflow_token.groups_shared_among).to match_array([token_group]) }
    end
  end

  describe '#destroy' do
    context 'when group owns the token' do
      before do
        workflow_token.groups_shared_among << other_group
      end

      subject! do
        post :destroy, params: { id: other_group.id, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.groups_shared_among).not_to include(other_group) }
    end

    context 'someone else tries to remove an ownership' do
      let(:third_user) { create(:confirmed_user) }

      before { login third_user }

      subject! do
        post :destroy, params: { id: token_group.id, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:success]).to be_nil }
      it { expect(workflow_token.groups_shared_among).to match_array([token_group]) }
    end
  end
end
