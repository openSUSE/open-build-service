require 'rails_helper'

RSpec.describe Webui::InterconnectsController do
  let(:confirmed_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  it { is_expected.to use_before_action(:require_admin) }

  describe 'GET #new' do
    context 'as admin' do
      before do
        login(admin_user)
        post :new
      end

      it { is_expected.to render_template('webui/interconnects/new') }
    end

    context 'as normal user' do
      before do
        login(confirmed_user)
        post :new
      end

      it { is_expected.to redirect_to(root_url) }
      it { expect(flash[:error]).to eq('Requires admin privileges') }
    end
  end

  describe 'POST #create' do
    context 'as admin' do
      before do
        login(admin_user)
        post :create, params: { project: attributes_for(:remote_project, name: 'MyRemoteProject') }
      end

      it { expect(response).to redirect_to(project_show_path('MyRemoteProject')) }
      it { expect(flash[:success]).to eq("Project 'MyRemoteProject' was successfully created.") }
      it { expect(RemoteProject.exists?(name: 'MyRemoteProject')).to be(true) }
    end
  end
end
