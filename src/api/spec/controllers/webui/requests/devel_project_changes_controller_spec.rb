require 'rails_helper'

RSpec.describe Webui::Requests::DevelProjectChangesController, type: :controller do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:devel_project) { create(:project, name: 'devel:project') }
  let(:devel_package) { create(:package_with_file, name: 'goal', project: devel_project) }
  let(:project) { submitter.home_project }
  let(:package) { create(:package, :as_submission_source, name: 'goal', project: project, develpackage: devel_package) }

  before do
    login(submitter)
  end

  describe 'GET #new' do
    context 'with devel project' do
      before do
        get :new, params: { project_name: project.name, package_name: package.name }
      end

      it { expect(response).to render_template(:new) }
    end

    context 'without devel project' do
      before do
        get :new, params: { project_name: devel_project.name, package_name: devel_package.name }
      end

      it { expect(flash[:error]).to eq("Package #{devel_package} doesn't have a devel project") }
      it { expect(response).to redirect_to(package_show_path(project: devel_project, package: devel_package)) }
    end
  end

  describe 'POST #create' do
    let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
    let(:new_devel_project) { receiver.home_project }
    let(:new_devel_package) { create(:package_with_file, name: 'goal', project: new_devel_project) }
    let(:bs_request) { BsRequest.find_by(description: 'change it!', creator: submitter.login) }

    context 'with valid parameters' do
      before do
        post :create, params: { project_name: project.name,
                                package_name: package.name,
                                bs_request: { description: 'change it!',
                                              bs_request_actions_attributes: { '0': { target_project: project.name,
                                                                                      target_package: package.name,
                                                                                      source_project: new_devel_project.name,
                                                                                      source_package: new_devel_package.name,
                                                                                      type: 'change_devel' } } } }
      end

      it { expect(response).to redirect_to(request_show_path(number: bs_request)) }
      it { expect(flash[:success]).to be(nil) }
      it { expect(bs_request).not_to be(nil) }
      it { expect(bs_request.description).to eq('change it!') }

      it 'creates a request action with correct data' do
        request_action = bs_request.bs_request_actions.where(type: 'change_devel',
                                                             target_project: project.name,
                                                             target_package: package.name,
                                                             source_project: new_devel_project.name,
                                                             source_package: new_devel_package.name)
        expect(request_action).to exist
      end
    end

    context 'with invalid devel_package parameter' do
      before do
        post :create, params: { project_name: project.name,
                                package_name: package.name,
                                bs_request: { description: 'change it!',
                                              bs_request_actions_attributes: { '0': { target_project: project.name,
                                                                                      target_package: package.name,
                                                                                      source_project: new_devel_project.name,
                                                                                      source_package: 'non-existant',
                                                                                      type: 'change_devel' } } } }
      end

      it { expect(flash[:error]).to eq("Package not found: #{new_devel_project}/non-existant") }
      it { expect(response).to redirect_to(package_show_path(project: project, package: package)) }
      it { expect(bs_request).to be(nil) }
    end
  end
end
