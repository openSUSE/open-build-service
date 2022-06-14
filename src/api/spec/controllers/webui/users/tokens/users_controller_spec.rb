require 'rails_helper'

RSpec.describe Webui::Users::Tokens::UsersController do
  let(:token_user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:workflow_token) { create(:workflow_token) }

  before do
    Flipper.enable(:trigger_workflow, token_user)
    login token_user
    workflow_token.users_shared_among << token_user
  end

  describe '#create' do
    render_views

    context 'when the user does not own the token yet' do
      subject! do
        post :create, params: { userid: other_user, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.users_shared_among).to match_array([token_user, other_user]) }
    end

    context 'when the user owns the token already' do
      before do
        workflow_token.users_shared_among << other_user
      end

      subject! do
        post :create, params: { userid: other_user, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.users_shared_among).to match_array([token_user, other_user]) }
    end

    context 'someone else tries to own the token' do
      let(:third_user) { create(:confirmed_user) }

      before { login third_user }

      subject! do
        post :create, params: { userid: third_user, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:success]).to be_nil }
      it { expect(workflow_token.users_shared_among).to match_array([token_user]) }
    end
  end

  describe '#destroy' do
    context 'when user owns the token' do
      before do
        workflow_token.users_shared_among << other_user
      end

      subject! do
        post :destroy, params: { id: other_user.id, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(token_users_path(workflow_token)) }
      it { expect(flash[:success]).to be_present }
      it { expect(workflow_token.users_shared_among).not_to(include(other_user)) }
    end

    context 'someone else tries to remove an ownership' do
      let(:third_user) { create(:confirmed_user) }

      before { login third_user }

      subject! do
        post :destroy, params: { id: token_user.id, token_id: workflow_token }
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:success]).to be_nil }
      it { expect(workflow_token.users_shared_among).to match_array([token_user]) }
    end
  end
end
