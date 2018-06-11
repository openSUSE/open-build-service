require 'rails_helper'

RSpec.describe SourceProjectConfigController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }

  describe 'GET #show' do
    before do
      login user
      get :show, params: { project: project }
    end

    it { expect(response).to be_success }
  end

  describe 'PUT #update' do
    before do
      login user
      put :update, params: { project: project, comment: 'Updated by test' }
    end

    it { expect(response).to be_success }
    it { expect(project.config.to_s).to include('Updated', 'by', 'test') }
  end
end
