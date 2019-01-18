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
           target_package: target_package,
           source_package: source_package,
           review_by_group: group)
  end

  before { login(manager) }

  describe 'POST #create' do
    context 'succeeds' do
      subject do
        post :create, params: { number: bs_request.number, staging_main_project_name: staging_workflow.project.name,
                                description: "I don't want to see you any more" }, format: :xml
      end

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(:success) }
      end

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(1)) }
    end

    context 'fails: project does not exist' do
      subject { post :create, params: { number: bs_request.number, staging_main_project_name: 'i_do_not_exist', description: "I don't want to see you any more" }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(404) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end

    context 'fails: project without staging_workflow' do
      let(:project_without_staging) { create(:project, name: 'no_staging') }
      subject { post :create, params: { number: bs_request.number, staging_main_project_name: project_without_staging, description: "I don't want to see you any more" }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(400) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end

    context 'fails: invalid request exclusion' do
      let(:project_without_staging) { create(:project, name: 'without_staging_wokflow') }
      subject { post :create, params: { number: bs_request.number, staging_main_project_name: project_without_staging }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(400) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end
  end

  describe 'DELETE #destroy' do
    let(:request_exclusion) { create(:request_exclusion, bs_request: bs_request, staging_workflow: staging_workflow) }

    context 'succeeds' do
      subject { delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, number: bs_request.number }, format: :xml }

      before { request_exclusion }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(:success) }
      end

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(-1)) }
    end

    context 'fails: request does not exist' do
      subject { delete :destroy, params: {  staging_main_project_name: staging_workflow.project.name, number: 43_543 }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(404) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end

    context 'fails: request not excluded' do
      subject { delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, number: bs_request.number }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(400) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end

    context 'fails: unable to destroy' do
      before do
        request_exclusion
        allow_any_instance_of(Staging::RequestExclusion).to receive(:destroy).and_return(false)
      end

      subject { delete :destroy, params: { staging_main_project_name: staging_workflow.project.name, number: bs_request.number }, format: :xml }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(400) }
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }
    end
  end
end
