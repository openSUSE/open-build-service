RSpec.describe Status::ReportsController do
  render_views

  let(:user) { create(:confirmed_user) }

  describe 'GET show' do
    context 'for bs_request' do
      let(:source_project) { create(:project_with_package) }
      let(:target_project) { create(:project_with_package, required_checks: ['openQA']) }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               creator: user,
               source_package: source_project.packages.first,
               target_package: target_project.packages.first)
      end
      let(:status_report) { create(:status_report, checkable: bs_request) }
      let!(:check) { create(:check, status_report: status_report, name: 'ExampleCI') }

      before { get :show, params: { bs_request_number: bs_request.number }, format: :xml }

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:checks)).to contain_exactly(check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('openQA') }
    end

    context 'for published repository' do
      let(:project) { create(:project_with_repository) }
      let(:repository) { project.repositories.first }
      let(:status_report) { create(:status_report, checkable: repository) }
      let!(:check) { create(:check, status_report: status_report, name: 'ExampleCI') }

      before do
        repository.update!(required_checks: ['openQA'])

        get :show, params: { project_name: project.name, repository_name: repository.name, report_uuid: status_report.uuid }, format: :xml
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:checks)).to contain_exactly(check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('openQA') }
    end

    context 'for built repository' do
      let(:project) { create(:project_with_repository) }
      let(:repository) { project.repositories.first }
      let(:repository_architecture) { create(:repository_architecture, repository: repository) }
      let(:status_report) { create(:status_report, checkable: repository_architecture) }
      let!(:check) { create(:check, status_report: status_report, name: 'ExampleCI') }

      before do
        repository_architecture.update!(required_checks: ['openQA'])

        get :show, params: { project_name: project.name, repository_name: repository.name,
                             arch: repository_architecture.architecture.name, report_uuid: status_report.uuid }, format: :xml
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:checks)).to contain_exactly(check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('openQA') }
    end
  end
end
