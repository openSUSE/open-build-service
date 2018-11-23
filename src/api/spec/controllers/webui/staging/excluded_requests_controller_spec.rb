require 'rails_helper'

RSpec.describe Webui::Staging::ExcludedRequestsController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:another_user) { create(:confirmed_user, login: 'another_user') }
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

    context 'succeeds' do
      subject { post :create, params: { staging_workflow_id: staging_workflow, staging_request_exclusion: { number: bs_request, description: description } } }

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(1)) }

      context 'response' do
        before { subject }

        it { expect(staging_workflow.request_exclusions.first.description).to eq(description) }
        it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
        it { expect(flash[:success]).not_to be_nil }
      end
    end

    context 'fails: invalid exclusion request' do
      subject { post :create, params: { staging_workflow_id: staging_workflow, staging_request_exclusion: { number: bs_request } } }

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end

    context "fails: user doesn't have permissions" do
      subject { post :create, params: { staging_workflow_id: staging_workflow, staging_request_exclusion: { number: bs_request, description: description } } }

      before do
        staging_workflow
        login(another_user)
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end
  end

  describe '#destroy' do
    let!(:request_exclusion) { create(:request_exclusion, staging_workflow: staging_workflow, bs_request: bs_request) }

    context 'succeeds' do
      subject { delete :destroy, params: { staging_workflow_id: staging_workflow, id: request_exclusion } }

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(-1)) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
        it { expect(flash[:success]).not_to be_nil }
      end
    end

    context 'fails: destroy not possible' do
      subject { delete :destroy, params: { staging_workflow_id: staging_workflow, id: request_exclusion } }

      before { allow_any_instance_of(Staging::RequestExclusion).to receive(:destroy).and_return(false) }

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(flash[:error]).not_to be_nil }
        it { expect(response).to redirect_to(staging_workflow_excluded_requests_path(staging_workflow)) }
      end
    end

    context "fails: users doesn't have permissions" do
      subject { delete :destroy, params: { staging_workflow_id: staging_workflow, id: request_exclusion } }

      before do
        staging_workflow
        login(another_user)
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end
  end
end
