require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Projects::MaintainedProjectsController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:opensuse_project) { create(:project, name: 'openSUSE') }
  let(:opensuse_project_update) { create(:project, name: 'openSUSE_Update') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project', target_project: opensuse_project) }

  describe 'GET #index' do
    context 'showing all projects' do
      before do
        get :index, params: { project_name: maintenance_project.name }, format: :html
      end

      it { expect(assigns(:project).name).to eq(maintenance_project.name) }
      it { is_expected.to render_template('webui/projects/maintained_projects/index') }
    end

    context 'datatable json' do
      let(:datatable_params) do
        { draw: '1',
          columns: { '0' => { 'data' => 'name', 'name' => '', 'searchable' => 'true', 'orderable' => 'true', 'search' => { 'value' => '', 'regex' => 'false' } },
                     '1' => { 'data' => 'actions', 'name' => '', 'searchable' => 'true', 'orderable' => 'true', 'search' => { 'value' => '', 'regex' => 'false' } } },
          order: { '0' => { 'column' => '0', 'dir' => 'asc' } }, start: '0' }
      end

      let(:json_response) { response.parsed_body }

      before do
        login user
        get :index, params: datatable_params.merge(project_name: maintenance_project.name), format: :json
      end

      it { expect(assigns(:project).name).to eq(maintenance_project.name) }
      it { expect(json_response).to be_key('recordsTotal') }
      it { expect(json_response['recordsTotal']).to eq(1) }
    end
  end

  describe 'POST #create' do
    context 'successfully create' do
      before do
        login admin_user
        post :create, params: { maintained_project: opensuse_project_update.name,
                                project_name: maintenance_project.name }, format: :html
      end

      it { expect(response).to redirect_to(action: :index, controller: 'webui/projects/maintained_projects') }
      it { expect(flash[:success]).to start_with('Enabled Maintenance for') }
    end
  end

  describe 'DELETE #destroy' do
    context 'successfully destroyed' do
      before do
        login admin_user
        delete :destroy, params: { maintained_project: opensuse_project.name,
                                   project_name: maintenance_project.name }, format: :html
      end

      it { expect(response).to redirect_to(action: :index, controller: 'webui/projects/maintained_projects') }
      it { expect(flash[:success]).to start_with('Disabled maintenance for') }
    end
  end
end
