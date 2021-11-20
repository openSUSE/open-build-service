require 'rails_helper'

RSpec.describe Webui::WorkflowRunsController, type: :controller do
  describe 'GET #index' do
    let(:token_user) { create(:confirmed_user) }
    let(:workflow_token) { create(:workflow_token, user: token_user) }
    let!(:workflow_run) { create(:workflow_run, token: workflow_token) }

    before do
      login token_user
      get :index, params: { token_id: workflow_token.id }
    end

    it { expect(assigns(:workflow_runs).count).to eq(1) }
  end
end
