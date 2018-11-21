require 'rails_helper'

RSpec.describe Webui::Staging::ExcludedRequestsController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }

  let(:source_package) { create(:package) }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_project: project.name,
           target_package: target_package.name,
           source_project: source_package.project.name,
           source_package: source_package.name)
  end

  before do
    login(user)
  end

  describe '#create' do
    let(:description) { Faker::Lorem.sentence }

    context 'success' do
      before do
        post :create, params: { staging_workflow_id: staging_workflow, staging_request_exclusion: { number: bs_request, description: description } }
      end

      it { expect(Staging::RequestExclusion.count).to eq(1) }
      it { expect(staging_workflow.request_exclusions.first.description).to eq(description) }
      it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context "doesn't exist" do
      before do
        allow_any_instance_of(Staging::RequestExclusion).to receive(:save).and_return(false)
        post :create, params: { staging_workflow_id: staging_workflow, staging_request_exclusion: { number: bs_request, description: description } }
      end

      it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end

  describe '#destroy' do
    let(:request_exclusion) { create(:request_exclusion, staging_workflow: staging_workflow, bs_request: bs_request) }

    context 'success' do
      before do
        delete :destroy, params: { staging_workflow_id: staging_workflow, id: request_exclusion }
      end

      it { expect(Staging::RequestExclusion.count).to eq(0) }
      it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'error' do
      before do
        allow_any_instance_of(Staging::RequestExclusion).to receive(:destroy).and_return(false)
        delete :destroy, params: { staging_workflow_id: staging_workflow, id: request_exclusion }
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
    end
  end
end
