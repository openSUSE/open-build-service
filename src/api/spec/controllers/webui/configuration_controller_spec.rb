require 'rails_helper'

RSpec.describe Webui::ConfigurationController do
  let(:confirmed_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe 'GET #index' do
    it { should use_before_action(:require_admin) }
  end

  describe 'POST #update' do
    it { should use_before_action(:require_admin) }
  end

  describe 'GET #interconnect' do
    it { should use_before_action(:require_admin) }
  end

  describe 'POST #create_interconnect' do
    it { should use_before_action(:require_admin) }

    context 'as admin' do
      it 'creates a new remote project' do
        login(admin_user)
        post :create_interconnect, project: attributes_for(:remote_project, name: 'MyRemoteProject')
        expect(response).to redirect_to(project_show_path('MyRemoteProject'))
        expect(flash[:notice]).to eq("Project 'MyRemoteProject' was created successfully")
        expect(RemoteProject.exists?(name: 'MyRemoteProject')).to be true
      end
    end
  end
end
