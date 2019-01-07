require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::ObsFactory::StagingProjectsController, type: :controller, vcr: true do
  render_views

  let(:description) do
    <<-DESCRIPTION
      requests:
        - { id: #{declined_bs_request.number} }
    DESCRIPTION
  end
  let(:factory) { create(:project, name: 'openSUSE:Factory') }
  let!(:factory_staging) { create(:project, name: 'openSUSE:Factory:Staging') }

  let(:factory_distribution) { ::ObsFactory::Distribution.find(factory.name) }
  let(:staging_projects) { ::ObsFactory::StagingProject.for(factory_distribution) }

  let(:source_package) { create(:package, :as_submission_source) }
  let(:target_package) { create(:package, name: 'target_package', project: factory) }
  let(:declined_bs_request) do
    create(:declined_bs_request,
           target_package: target_package,
           source_package: source_package)
  end

  before do
    create(:project, name: 'openSUSE:Factory:Staging:A', description: description)
    create(:project, name: 'openSUSE:Factory:Staging:B', description: 'Factory staging project B')
  end

  describe 'GET #index' do
    context 'without dashboard package' do
      subject! do
        get :index, params: { project: factory }
      end

      it { is_expected.to have_http_status(:success) }
      it { is_expected.to render_template(:index) }

      it 'sets up the required variables' do
        expect(assigns(:backlog_requests_ignored)).to be_empty
        expect(assigns(:backlog_requests)).to be_empty
        expect(assigns(:requests_state_new)).to be_empty
        expect(assigns(:project)).to eq(factory)
      end
    end

    context 'with dashboard package' do
      let!(:dashboard) { create(:package, name: 'dashboard', project: factory_staging) }

      context 'with ignored_requests file' do
        let(:backend_url) { "#{CONFIG['source_url']}/source/#{factory_staging}/#{dashboard}/ignored_requests" }

        context 'with content' do
          let(:target_package) { create(:package, name: 'target_package', project: factory) }
          let(:source_project) { create(:project, name: 'source_project') }
          let(:source_package) { create(:package, name: 'source_package', project: source_project) }
          let(:group) { create(:group, title: 'factory-staging') }
          let!(:create_review_requests) do
            [613_048, 99_999].map do |number|
              create(:bs_request_with_submit_action,
                     number: number,
                     review_by_group: group.title,
                     target_package: target_package,
                     source_package: source_package)
            end
          end
          let!(:create_review_requests_in_state_new) do
            [617_649, 111_111].map do |number|
              create(:bs_request_with_submit_action,
                     number: number,
                     review_by_group: group.title,
                     state: :new,
                     target_package: target_package,
                     source_package: source_package)
            end
          end
          let(:backend_response) do
            <<~TEXT
              613048: Needs to come in sync with Mesa changes (libwayland-egl1 is also built by Mesa.spec)
              617649: Needs a perl fix - https://rt.perl.org/Public/Bug/Display.html?id=133295
            TEXT
          end

          before do
            allow_any_instance_of(Package).to receive(:file_exists?).with('ignored_requests').and_return(true)
            stub_request(:get, backend_url).and_return(body: backend_response)
          end

          subject! do
            get :index, params: { project: factory }
          end

          it { is_expected.to have_http_status(:success) }
          it { is_expected.to render_template(:index) }

          it 'sets up the required variables' do
            expect(assigns(:backlog_requests_ignored)).to contain_exactly(create_review_requests.first)
            expect(assigns(:backlog_requests)).to contain_exactly(create_review_requests.last)
            expect(assigns(:requests_state_new)).to contain_exactly(create_review_requests_in_state_new.last)
            expect(assigns(:project)).to eq(factory)
          end
        end

        context 'without content' do
          before do
            allow_any_instance_of(Package).to receive(:file_exists?).with('ignored_requests').and_return(true)

            stub_request(:get, backend_url).and_return(body: '')
          end

          subject! do
            get :index, params: { project: factory }
          end

          it { is_expected.to have_http_status(:success) }
          it { is_expected.to render_template(:index) }

          it 'sets up the required variables' do
            expect(assigns(:backlog_requests_ignored)).to be_empty
            expect(assigns(:backlog_requests)).to be_empty
            expect(assigns(:requests_state_new)).to be_empty
            expect(assigns(:project)).to eq(factory)
          end
        end
      end
    end

    context 'requesting json' do
      subject { get :index, params: { project: factory }, format: :json }

      it { is_expected.to have_http_status(:success) }
      it 'responds with a json representation of the staging project' do
        expect(JSON.parse(subject.body)).to eq(JSON.parse(staging_projects.to_json))
      end
    end
  end

  describe 'GET #show' do
    context 'with a existent factory_staging_project' do
      context 'requesting html' do
        subject! { get :show, params: { project: factory, project_name: 'A' } }

        it { is_expected.to have_http_status(:success) }
        it { is_expected.to render_template(:show) }
        it { expect(assigns(:staging_project).obsolete_requests).to contain_exactly(declined_bs_request) }
      end

      context 'requesting json' do
        subject { get :show, params: { project: factory, project_name: 'A' }, format: :json }

        it { is_expected.to have_http_status(:success) }
        it 'responds with a json representation of the staging project' do
          response = JSON.parse(subject.body)
          expect(response).to include(
            'name' => 'openSUSE:Factory:Staging:A',
            'description' => description,
            'obsolete_requests' => [JSON.parse(declined_bs_request.to_json)],
            'overall_state' => 'unacceptable'
          )
        end
      end

      context 'with checks' do
        let(:one_request) do
          create(:bs_request_with_submit_action,
                 target_project: factory,
                 source_package: source_package)
        end
        let(:meta) do
          <<-DESCRIPTION
                     requests:
                       - { id: #{one_request.number} }
          DESCRIPTION
        end
        let(:factory_staging_d) { create(:project, name: 'openSUSE:Factory:Staging:D', description: meta) }
        let!(:images_repository) { create(:repository, project: factory_staging_d, name: 'images', architectures: ['local']) }
        let(:images_local_arch) { images_repository.repository_architectures.first }
        let(:published_report) { create(:status_report, checkable: images_repository) }
        let(:build_report) { create(:status_report, checkable: images_local_arch) }

        before do
          path = "#{CONFIG['source_url']}/published/openSUSE:Factory:Staging:D/images?view=status"
          d_status = "<status code='succeeded'><starttime>1541096739</starttime><endtime>1541096742</endtime><buildid>#{published_report.uuid}</buildid></status>"
          stub_request(:get, path).and_return(body: d_status)

          path = "#{CONFIG['source_url']}/build/openSUSE:Factory:Staging:D/images/local?view=status"
          d_status = "<status code='succeeded'><starttime>1541096739</starttime><endtime>1541096742</endtime><buildid>#{build_report.uuid}</buildid></status>"
          stub_request(:get, path).and_return(body: d_status)
        end

        context 'has no checks at all' do
          it 'returns acceptable' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [],
              'overall_state' => 'acceptable'
            )
          end
        end

        context 'required check on published repo' do
          before do
            images_repository.required_checks = ['openqa']
            images_repository.save
          end

          it 'returns missing check' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            expect(JSON.parse(response.body)).to include(
              'missing_checks' => ['openqa'],
              'checks' => [],
              'overall_state' => 'testing'
            )
          end
        end

        context 'required check on build repo' do
          before do
            images_local_arch.required_checks = ['openqa']
            images_local_arch.save
          end

          it 'returns missing check' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            expect(JSON.parse(response.body)).to include(
              'missing_checks' => ['openqa'],
              'checks' => [],
              'overall_state' => 'testing'
            )
          end
        end

        context 'published repo has pending check' do
          let!(:check) { create(:check, name: 'openqa', state: 'pending', status_report: published_report) }

          it 'returns testing' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'testing'
            )
          end
        end

        context 'published repo has failed check' do
          let!(:check) { create(:check, name: 'openqa', state: 'failure', status_report: published_report) }

          it 'returns failed' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'failed'
            )
          end
        end

        context 'published repo has succeeded check' do
          let!(:check) { create(:check, name: 'openqa', state: 'success', status_report: published_report) }

          it 'returns acceptable' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'acceptable'
            )
          end
        end

        context 'published repo has failed check but wrong buildid' do
          let!(:check) { create(:check, name: 'openqa', state: 'failure', status_report: published_report) }

          before do
            published_report.uuid = 'doesnotmatch'
            published_report.save
          end

          it 'returns acceptable without required checks' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [],
              'overall_state' => 'acceptable'
            )
          end

          it 'returns testing with required checks' do
            images_repository.required_checks = ['openqa']
            images_repository.save

            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => ['openqa'],
              'checks' => [],
              'overall_state' => 'testing'
            )
          end
        end

        context 'required check on build repo' do
          before do
            images_local_arch.required_checks = ['openqa']
            images_local_arch.save
          end

          it 'returns missing check' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            expect(JSON.parse(response.body)).to include(
              'missing_checks' => ['openqa'],
              'checks' => [],
              'overall_state' => 'testing'
            )
          end
        end

        context 'build repo has pending check' do
          let!(:check) { create(:check, name: 'openqa', state: 'pending', status_report: build_report) }

          it 'returns testing' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'testing'
            )
          end
        end

        context 'build repo has failed check' do
          let!(:check) { create(:check, name: 'openqa', state: 'failure', status_report: build_report) }

          it 'returns failed' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'failed'
            )
          end
        end

        context 'build repo has succeeded check' do
          let!(:check) { create(:check, name: 'openqa', state: 'success', status_report: build_report) }

          it 'returns acceptable' do
            get :show, params: { project: factory, project_name: 'D' }, format: :json
            expect(response).to have_http_status(:success)

            json_hash = JSON.parse(response.body)
            expect(json_hash).to include(
              'missing_checks' => [],
              'checks' => [check.serializable_hash],
              'overall_state' => 'acceptable'
            )
          end
        end
      end
    end

    context 'with a non-existent factory_staging_project' do
      subject { get :show, params: { project: factory, project_name: 'C' } }

      it { is_expected.to have_http_status(:found) }
      it { is_expected.to redirect_to(root_path) }
    end
  end
end
