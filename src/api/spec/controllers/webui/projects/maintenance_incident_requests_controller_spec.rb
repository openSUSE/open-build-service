require 'rails_helper'

RSpec.describe Webui::Projects::MaintenanceIncidentRequestsController do
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project') }

  describe 'POST #create' do
    before do
      login admin_user
      request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
    end

    it 'without an existent project will raise an exception' do
      expect { post :create, params: { project_name: 'non:existent:project' } }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'without a proper action for the maintenance project' do
      before do
        post :create, params: { project_name: maintenance_project, description: 'Fake description for a request' }
      end

      it { expect(flash[:error]).to eq('MaintenanceHelper::MissingAction') }
      it { is_expected.to redirect_to(root_url) }
    end

    context 'with the proper params' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_return(true)
        post :create, params: { project_name: maintenance_project, description: 'Fake description for a request' }
      end

      it { expect(flash[:success]).to eq('Created maintenance incident request') }
      it { is_expected.to redirect_to(project_show_path(maintenance_project)) }
    end
  end
end
