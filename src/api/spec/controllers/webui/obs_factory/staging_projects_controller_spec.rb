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

  let(:source_package) { create(:package) }
  let(:target_package) { create(:package, name: 'target_package', project: factory) }
  let(:declined_bs_request) do
    create(:declined_bs_request,
           target_project: factory.name,
           target_package: target_package.name,
           source_project: source_package.project.name,
           source_package: source_package.name)
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
              create(:review_bs_request_by_group,
                     number: number,
                     reviewer: group.title,
                     target_project: factory.name,
                     target_package: target_package.name,
                     source_project: source_package.project.name,
                     source_package: source_package.name)
            end
          end
          let!(:create_review_requests_in_state_new) do
            [617_649, 111_111].map do |number|
              create(:review_bs_request_by_group,
                     number: number,
                     reviewer: group.title,
                     request_state: 'new',
                     target_project: factory.name,
                     target_package: target_package.name,
                     source_project: source_package.project.name,
                     source_package: source_package.name)
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
            'name'              => 'openSUSE:Factory:Staging:A',
            'description'       => description,
            'obsolete_requests' => [JSON.parse(declined_bs_request.to_json)],
            'overall_state'     => 'unacceptable'
          )
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
