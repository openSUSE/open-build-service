require 'rails_helper'

RSpec.describe Status::ReportsController, type: :controller do
  render_views

  let(:user) { create(:confirmed_user) }

  describe 'GET show' do
    context 'for bs_request' do
      let(:source_project) { create(:project_with_package) }
      let(:target_project) { create(:project_with_package, required_checks: ['openQA']) }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               creator: user,
               source_project: source_project,
               source_package: source_project.packages.first,
               target_project: target_project,
               target_package: target_project.packages.first)
      end
      let(:status_report) { create(:status_report, checkable: bs_request) }
      let!(:check) { create(:check, status_report: status_report, name: 'ExampleCI') }

      subject! { get :show, params: { bs_request_number: bs_request.number }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(assigns(:checks)).to contain_exactly(check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('openQA') }
    end

    context 'for repository' do
      let(:project) { create(:project_with_repository) }
      let(:repository) { project.repositories.first }
      let(:status_report) { create(:status_report, checkable: repository) }
      let!(:check) { create(:check, status_report: status_report, name: 'ExampleCI') }

      before do
        repository.update_attributes!(required_checks: ['openQA'])
      end

      subject! { get :show, params: { project_name: project.name, repository_name: repository.name, report_uuid: status_report.uuid }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(assigns(:checks)).to contain_exactly(check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('openQA') }
    end
  end
end
