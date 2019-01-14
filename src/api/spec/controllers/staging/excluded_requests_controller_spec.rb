require 'rails_helper'

RSpec.describe Staging::ExcludedRequestsController, type: :controller, vcr: true do
  let(:user) { create(:confirmed_user, login: 'user') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:manager) { create(:confirmed_user, login: 'manager', groups: [group]) }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           creator: other_user,
           target_project: project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name,
           review_by_group: group)
  end

  before { login(manager) }

  describe 'POST #create' do
    context 'succeeds' do
      before do
        post :create, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request number='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      subject { staging_workflow.request_exclusions.last }

      it { expect(response).to have_http_status(:success) }
      it { expect(subject.bs_request).to eq(bs_request) }
      it { expect(subject.description).to eq('hey') }
    end

    context 'fails: project does not exist' do
      before do
        post :create, params: { staging_main_project_name: 'i_do_not_exist', format: :xml },
                      body: "<excluded_requests><request number='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'fails: project without staging_workflow' do
      let(:project_without_staging) { create(:project, name: 'no_staging') }
      before do
        post :create, params: { staging_main_project_name: project_without_staging, format: :xml },
                      body: "<excluded_requests><request number='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(400) }
    end

    context 'fails: no description, invalid request exclusion' do
      before do
        post :create, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request number='#{bs_request.number}'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(400) }
    end

    context 'fails: non-existant bs_request number, invalid request exclusion' do
      before do
        post :create, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request number='43_543'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(400) }
    end
  end

  describe 'DELETE #destroy' do
    let(:request_exclusion) { create(:request_exclusion, bs_request: bs_request, number: bs_request.number, staging_workflow: staging_workflow) }

    context 'succeeds' do
      before { request_exclusion }

      subject do
        delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                         body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(-1)) }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(:success) }
      end
    end

    context 'fails: request not excluded' do
      before do
        delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                         body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(400) }
    end

    context 'fails: unable to destroy' do
      before do
        request_exclusion
        allow_any_instance_of(ActiveRecord::Relation).to receive(:destroy_all).and_return([])
        delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, format: :xml },
                         body: "<requests><number>#{bs_request.number}</number></requests>"
      end

      it { expect(response).to have_http_status(400) }
    end
  end
end
