require 'rails_helper'

RSpec.describe Status::ReportsController, type: :controller do
  render_views

  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project_with_repository) }
  let(:source_project) { create(:project_with_package) }
  let(:target_project) { create(:project_with_package) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           creator: user,
           source_project: source_project,
           source_package: source_project.packages.first,
           target_project: target_project,
           target_package: target_project.packages.first)
  end

  before do
    login user
  end

  describe 'GET index' do
    let(:repository) { project.repositories.first }
    let!(:status_report_for_repository) { create(:status_report, checkable: repository) }
    let!(:status_report_for_bs_request) { create(:status_report, checkable: bs_request) }

    context 'when status reports of bs request is requested' do
      subject! { get :index, params: { bs_request_number: bs_request.number }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(assigns(:status_reports)).to contain_exactly(status_report_for_bs_request) }
    end

    context 'when status reports of repository is requested' do
      subject! { get :index, params: { project_name: project.name, repository_name: repository.name }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(assigns(:status_reports)).to contain_exactly(status_report_for_repository) }
    end
  end

  describe 'GET show' do
    let(:repository) { project.repositories.first }
    let!(:status_report) { create(:status_report, checkable: repository) }

    context 'when status report exists' do
      subject! { get :show, params: { project_name: project.name, repository_name: repository.name, uuid: status_report.uuid }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(assigns(:status_report)).to eq(status_report) }
    end

    context 'when status report does not exists' do
      subject! { get :show, params: { project_name: project.name, repository_name: repository.name, uuid: 42 }, format: :xml }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'DELETE destroy' do
    let(:repository) { project.repositories.first }
    let!(:status_report) { create(:status_report, checkable: repository) }

    context 'with permissions' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      subject! { delete :destroy, params: { project_name: project.name, repository_name: repository.name, uuid: status_report.uuid }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(repository.status_reports).to be_empty }
    end

    context 'without permissions' do
      subject! { delete :destroy, params: { project_name: project.name, repository_name: repository.name, uuid: status_report.uuid }, format: :xml }

      it { is_expected.to have_http_status(:forbidden) }
      it { expect(repository.status_reports).not_to be_empty }
    end
  end
end
