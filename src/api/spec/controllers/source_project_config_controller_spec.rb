require 'rails_helper'

RSpec.describe SourceProjectConfigController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }
  let(:remote_project) { create(:remote_project) }

  describe 'GET #show' do
    context 'when the home project exist' do
      before do
        login user
        get :show, params: { project: project }
      end

      it { expect(response).to be_success }
    end

    context 'when the project doesnt exist' do
      before do
        login user
        get :show, params: { project: 'home:foobar', format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'PUT #update' do
    context 'we are trying to update a remote project' do
      before do
        login user
        put :update, params: { project: remote_project.name,
             comment: 'Updated by test', format: :xml }
      end

      it { expect(response).to be_forbidden }
    end

    context 'we are trying to update a project' do
      before do
        login user
        put :update, params: { project: project, comment: 'Updated by test' }
      end

      it { expect(response).to be_success }
      it { expect(project.config.to_s).to include('Updated', 'by', 'test') }
    end
  end
end
