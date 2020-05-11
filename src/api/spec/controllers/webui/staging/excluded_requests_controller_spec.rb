require 'rails_helper'

RSpec.describe Webui::Staging::ExcludedRequestsController, type: :controller do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:another_user) { create(:confirmed_user, login: 'another_user') }
  let(:project) { user.home_project }
  let!(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }

  let(:source_package) { create(:package) }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end

  before do
    login(user)
  end

  describe '#create' do
    let(:description) { Faker::Lorem.sentence }

    context 'succeeds' do
      subject { post :create, params: { workflow_project: staging_workflow.project, staging_request_exclusion: { number: bs_request, description: description } } }

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(1)) }

      context 'response' do
        before { subject }

        it { expect(staging_workflow.request_exclusions.first.description).to eq(description) }
        it { expect(response).to redirect_to(excluded_requests_path(staging_workflow.project)) }
        it { expect(flash[:success]).not_to be_nil }
      end
    end

    context 'fails: invalid exclusion request' do
      subject { post :create, params: { workflow_project: staging_workflow.project, staging_request_exclusion: { number: bs_request } } }

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(excluded_requests_path(staging_workflow.project)) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end

    context "fails: user doesn't have permissions" do
      subject { post :create, params: { workflow_project: staging_workflow.project, staging_request_exclusion: { number: bs_request, description: description } } }

      before do
        login(another_user)
      end

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(root_path) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end

    context 'fails: request belongs to a staging project' do
      subject { post :create, params: { workflow_project: staging_workflow.project, staging_request_exclusion: { number: bs_request, description: description } } }

      before do
        bs_request.staging_project = staging_workflow.staging_projects.first
        bs_request.save
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
      subject { delete :destroy, params: { workflow_project: staging_workflow.project, id: request_exclusion } }

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(-1)) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(excluded_requests_path(staging_workflow.project)) }
        it { expect(flash[:success]).not_to be_nil }
      end
    end

    context 'fails: destroy not possible' do
      subject { delete :destroy, params: { workflow_project: staging_workflow.project, id: request_exclusion } }

      before { allow_any_instance_of(Staging::RequestExclusion).to receive(:destroy).and_return(false) }

      it { expect { subject }.not_to(change { staging_workflow.request_exclusions.count }) }

      context 'response' do
        before { subject }

        it { expect(response).to redirect_to(excluded_requests_path(staging_workflow.project)) }
        it { expect(flash[:error]).not_to be_nil }
      end
    end

    context "fails: users doesn't have permissions" do
      subject { delete :destroy, params: { workflow_project: staging_workflow.project, id: request_exclusion } }

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
