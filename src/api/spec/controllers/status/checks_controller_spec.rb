require 'rails_helper'

RSpec.describe Status::ChecksController, type: :controller do
  render_views

  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project) }
  let(:repository) { create(:repository, project: project) }
  let(:status_report) { create(:status_report, checkable: repository) }

  before do
    login user
  end

  describe 'POST update' do
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

    context 'when status report exists and check does not exist' do
      shared_examples 'does create the check' do
        let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

        context 'successfully' do
          subject! { post :update, body: xml, params: params, format: :xml }

          it 'creates create a new check' do
            expect(status_report.checks.where(name: 'ci/example: example test', short_description: 'The test failed on Example CI',
                                              state: 'pending', url: 'http://checks.example.com/12345')).to exist
          end
          it { is_expected.to have_http_status(:success) }
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

          subject! { post :update, body: xml, params: params, format: :xml }

          it { is_expected.to have_http_status(:unprocessable_entity) }
          it { expect(status_report.checks).to be_empty }
        end

        context 'with no permissions' do
          let(:other_user) { create(:confirmed_user) }

          before do
            login(other_user)
          end

          subject! { post :update, body: xml, params: params, format: :xml }

          it { is_expected.to have_http_status(:forbidden) }
          it { expect(status_report.checks).to be_empty }
        end
      end

      context 'for a repository' do
        let(:params) do
          { report_uuid: status_report.uuid, repository_name: repository.name, project_name: project.name }
        end

        include_context 'does create the check'
      end

      context 'for a request' do
        let(:source_package) { create(:package) }
        let(:source_project) { source_package.project }
        let(:bs_request) { create(:bs_request_with_submit_action, target_project: project, source_project: source_project, source_package: source_package) }
        let!(:status_report) { create(:status_report, checkable: bs_request) }
        let(:params) do
          { bs_request_number: bs_request.number }
        end

        include_context 'does create the check'
      end
    end

    context 'when status report and check do not exist' do
      context 'checkable is bs request' do
        let(:source_project) { create(:project_with_package) }
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 source_project: source_project,
                 source_package: source_project.packages.first,
                 target_project: project)
        end
        let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

        subject! { post :update, body: xml, params: { bs_request_number: bs_request.number }, format: :xml }

        it 'creates a new status report' do
          expect(bs_request.status_reports).to exist
        end
        it { is_expected.to have_http_status(:success) }
      end

      context 'checkable is a repository' do
        let(:project) { create(:project) }
        let(:repository) { create(:repository, project: project) }
        let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

        subject! { post :update, body: xml, params: { project_name: project.name, repository_name: repository.name, report_uuid: '1234' }, format: :xml }

        it 'creates a new status report' do
          expect(repository.status_reports.where(uuid: '1234')).to exist
        end
        it { is_expected.to have_http_status(:success) }
      end
    end

    context 'when check exists' do
      let(:valid_xml) { '<check><name>openQA</name><state>success</state></check>' }

      shared_examples 'does update the check' do
        context 'successfully' do
          let!(:relationship) { create(:relationship_project_user, user: user, project: project) }

          subject! { post :update, body: valid_xml, params: params, format: :xml }

          it { is_expected.to have_http_status(:success) }
          it { expect(check.reload.state).to eq('success') }
        end

        context 'without permissions' do
          subject! do
            post :update, body: valid_xml, params: params, format: :xml
          end

          it { is_expected.to have_http_status(:forbidden) }
          it { expect(check.reload.state).to eq('pending') }
        end

        context 'with xml with empty element' do
          let!(:relationship) { create(:relationship_project_user, user: user, project: project) }
          let(:xml_with_empty_field) { '<check><short_description/></check>' }

          subject! { post :update, body: xml_with_empty_field, params: params, format: :xml }

          it { is_expected.to have_http_status(:unprocessable_entity) }
          it { expect(check.reload.short_description).to eq(check.short_description) }
        end

        context 'with invalid xml' do
          let!(:relationship) { create(:relationship_project_user, user: user, project: project) }
          let(:invalid_xml) { '<check><state>not-allowed</state></check>' }

          subject! { post :update, body: invalid_xml, params: params, format: :xml }

          it { is_expected.to have_http_status(:unprocessable_entity) }
          it { expect(check.reload.state).to eq('pending') }
        end
      end

      context 'for a repository' do
        let!(:check) { create(:check, name: 'openQA', state: 'pending', status_report: status_report) }
        let(:params) do
          { report_uuid: status_report.uuid, repository_name: repository.name, project_name: project.name }
        end

        include_context 'does update the check'
      end

      context 'for a request' do
        let(:source_package) { create(:package) }
        let(:source_project) { source_package.project }
        let(:bs_request) { create(:bs_request_with_submit_action, target_project: project, source_project: source_project, source_package: source_package) }
        let(:status_report) { create(:status_report, checkable: bs_request) }
        let!(:check) { create(:check, name: 'openQA', state: 'pending', status_report: status_report) }
        let(:params) do
          { bs_request_number: bs_request.number }
        end

        include_context 'does update the check'
      end
    end
  end
end
