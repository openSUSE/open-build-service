require 'rails_helper'

RSpec.describe Status::ChecksController, type: :controller do
  render_views

  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project_with_repository) }
  let(:status_report) { create(:status_report, checkable: project.repositories.first) }

  before do
    login user
  end

  describe 'GET index' do
    context 'with checks' do
      let(:repository) { project.repositories.first }
      let!(:check) { create(:check, status_report: status_report) }
      let!(:other_check) { create(:check, status_report: status_report) }

      before do
        repository.update(required_checks: ['missing'])
      end

      subject! { get :index, params: { report_uuid: status_report.uuid }, format: :xml }

      it { expect(assigns(:checks)).to contain_exactly(check, other_check) }
      it { expect(assigns(:missing_checks)).to contain_exactly('missing') }
    end

    context 'without checks' do
      subject! { get :index, params: { report_uuid: status_report.uuid }, format: :xml }

      it { expect(assigns(:checks)).to be_empty }
    end
  end

  describe 'GET show' do
    let!(:check) { create(:check, status_report: status_report) }

    context 'when check exists' do
      subject! { get :show, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { expect(assigns(:check)).to eq(check) }
    end

    context 'when check does not exists' do
      subject! { get :show, params: { report_uuid: status_report.uuid, id: 42 }, format: :xml }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'POST create' do
    let!(:relationship) { create(:relationship_project_user, user: user, project: project) }
    let(:xml) do
      <<~XML
        <check>
          <url>http://checks.example.com/12345</url>
          <state>pending</state>
          <short_description>The test failed on Example CI</short_description>
          <name>ci/example: example test</name>
        </check>
      XML
    end

    context 'status report already exists' do
      context 'successfully' do
        subject! { post :create, body: xml, params: { report_uuid: status_report.uuid }, format: :xml }

        it 'creates create a new check' do
          expect(status_report.checks.where(name: 'ci/example: example test', short_description: 'The test failed on Example CI',
                                            state: 'pending', url: 'http://checks.example.com/12345')).to exist
        end
      end

      context 'with invalid XML' do
        let(:xml) do
          <<~XML
            <check>
              <url>http://checks.example.com/12345</url>
              <state>not-valid</state>
              <short_description>The test failed on Example CI</short_description>
              <name></name>
            </check>
          XML
        end

        subject! { post :create, body: xml, params: { report_uuid: status_report.uuid }, format: :xml }

        it { is_expected.to have_http_status(:unprocessable_entity) }
        it { expect(status_report.checks).to be_empty }
      end

      context 'with no permissions' do
        let(:other_user) { create(:confirmed_user) }

        before do
          login(other_user)
        end

        subject! { post :create, body: xml, params: { report_uuid: status_report.uuid }, format: :xml }

        it { is_expected.to have_http_status(:forbidden) }
        it { expect(status_report.checks).to be_empty }
      end
    end

    context 'status report does not exist yet' do
      context 'checkable is bs request' do
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
        let(:status_report) { create(:status_report, checkable: bs_request) }
        let!(:relationship) { create(:relationship_project_user, user: user, project: target_project) }

        subject! { post :create, body: xml, params: { bs_request_number: bs_request.number, report_uuid: status_report.uuid }, format: :xml }

        it 'creates a status_report' do
          expect(bs_request.status_reports.count).to eq(1)
        end

        it 'creates create a new check' do
          expect(bs_request.status_reports.first.checks.where(name: 'ci/example: example test', short_description: 'The test failed on Example CI',
                                            state: 'pending', url: 'http://checks.example.com/12345')).to exist
        end
      end

      context 'checkable is a repository' do
        let(:project) { create(:project_with_repository) }
        let(:repository) { project.repositories.first }
        let(:status_report) { create(:status_report, checkable: repository) }
        let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

        subject! { post :create, body: xml, params: { project_name: project.title, repository_name: repository.name, report_uuid: status_report.uuid }, format: :xml }

        it 'creates create a new check' do
          expect(status_report.checks.where(name: 'ci/example: example test', short_description: 'The test failed on Example CI',
                                            state: 'pending', url: 'http://checks.example.com/12345')).to exist
        end
      end
    end
  end

  describe 'PUT update' do
    let!(:check) { create(:check, state: 'pending', status_report: status_report) }
    let(:valid_xml) { '<check><state>success</state></check>' }
    let(:invalid_xml) { '<check><state>not-allowed</state></check>' }

    context 'successfully' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      subject! { put :update, body: valid_xml, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(check.reload.state).to eq('success') }
    end

    context 'without permissions' do
      subject! { put :update, body: valid_xml, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { is_expected.to have_http_status(:forbidden) }
      it { expect(check.reload.state).to eq('pending') }
    end

    context 'with invalid xml' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      subject! { put :update, body: invalid_xml, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { is_expected.to have_http_status(:unprocessable_entity) }
      it { expect(check.reload.state).to eq('pending') }
    end
  end

  describe 'DELETE destroy' do
    let!(:check) { create(:check, status_report: status_report) }

    context 'with permissions' do
      let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

      subject! { delete :destroy, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { is_expected.to have_http_status(:success) }
      it { expect(status_report.checks).to be_empty }
    end

    context 'without permissions' do
      subject! { delete :destroy, params: { report_uuid: status_report.uuid, id: check.id }, format: :xml }

      it { is_expected.to have_http_status(:forbidden) }
      it { expect(status_report.checks).not_to be_empty }
    end
  end
end
