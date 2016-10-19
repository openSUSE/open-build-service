require 'rails_helper'

RSpec.describe Webui::ConfigurationController do
  let(:confirmed_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  it { is_expected.to use_before_action(:require_admin) }

  describe 'POST #create_interconnect' do
    context 'as admin' do
      it 'creates a new remote project' do
        login(admin_user)
        post :create_interconnect, params: { project: attributes_for(:remote_project, name: 'MyRemoteProject') }
        expect(response).to redirect_to(project_show_path('MyRemoteProject'))
        expect(flash[:notice]).to eq("Project 'MyRemoteProject' was created successfully")
        expect(RemoteProject.exists?(name: 'MyRemoteProject')).to be true
      end
    end
  end
end
