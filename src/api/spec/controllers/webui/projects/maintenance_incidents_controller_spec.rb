# typed: false
require 'rails_helper'

RSpec.describe Webui::Projects::MaintenanceIncidentsController do
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project') }

  describe 'GET #index' do
    context 'with maintenance incident' do
      let(:maintenance_incident) { create(:maintenance_incident_project, name: "#{maintenance_project}:incident", maintenance_project: maintenance_project) }
      let(:maintenance_incident_repo) { create(:repository, project: maintenance_incident) }
      let(:release_target) { create(:release_target, repository: maintenance_incident_repo, trigger: 'maintenance') }

      before do
        login admin_user
        release_target
        get :index, params: { project_name: maintenance_project }
      end

      it { expect(assigns(:incidents)).to eq([maintenance_incident]) }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'without maintenance incident' do
      before do
        login admin_user
        get :index, params: { project_name: maintenance_project }
      end

      it { expect(assigns(:incidents)).to be_empty }
      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe 'POST #create' do
    before do
      login admin_user
    end

    context 'with a Maintenance project' do
      # Needed because we can't see local variables of the controller action
      let(:new_maintenance_incident_project) { Project.maintenance_incident.first }

      before do
        post :create, params: { project_name: maintenance_project }
      end

      it { is_expected.to redirect_to(project_show_path(project: new_maintenance_incident_project.name)) }
      it { expect(flash[:success]).to start_with("Created maintenance incident project #{new_maintenance_incident_project.name}") }
    end

    context 'without a Maintenance project' do
      before do
        post :create, params: { project_name: apache_project }
      end

      it { is_expected.to redirect_to(project_show_path(project: apache_project)) }
      it { expect(flash[:error]).to eq('Incident projects shall only create below maintenance projects.') }
    end
  end

  describe 'POST #create_request' do
    before do
      login admin_user
      request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
    end

    it 'without an existent project will raise an exception' do
      expect { post :create_request, params: { project_name: 'non:existent:project' } }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'without a proper action for the maintenance project' do
      before do
        post :create_request, params: { project_name: maintenance_project, description: 'Fake description for a request' }
      end

      it { expect(flash[:error]).to eq('MaintenanceHelper::MissingAction') }
      it { is_expected.to redirect_to(root_url) }
    end

    context 'with the proper params' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_return(true)
        post :create_request, params: { project_name: maintenance_project, description: 'Fake description for a request' }
      end

      it { expect(flash[:success]).to eq('Created maintenance incident request') }
      it { is_expected.to redirect_to(project_show_path(maintenance_project)) }
    end
  end
end
