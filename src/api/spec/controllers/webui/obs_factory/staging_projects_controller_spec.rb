require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::ObsFactory::StagingProjectsController, type: :controller, vcr: true do
  render_views

  let(:factory) { create(:project, name: 'openSUSE:Factory') }
  let!(:factory_staging_a) { create(:project, name: 'openSUSE:Factory:Staging:A', description: 'Factory staging project A') }

  describe 'GET #index' do
    let!(:factory_staging) { create(:project, name: 'openSUSE:Factory:Staging') }

    context 'without dashboard package' do
      before do
        get :index, params: { project: factory }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template(:index) }

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

            get :index, params: { project: factory }
          end

          it { expect(response).to have_http_status(:success) }
          it { expect(response).to render_template(:index) }

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
            get :index, params: { project: factory }
          end

          it { expect(response).to have_http_status(:success) }
          it { expect(response).to render_template(:index) }

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
      let!(:factory_staging_b) { create(:project, name: 'openSUSE:Factory:Staging:B', description: '') }
      let(:factory_distribution) { ::ObsFactory::Distribution.find(factory.name) }
      let(:staging_projects) { ::ObsFactory::StagingProject.for(factory_distribution) }

      subject { get :index, params: { project: factory }, format: :json }

      it { is_expected.to have_http_status(:success) }
      it 'responds with a json representation of the staging project' do
        expect(JSON.parse(subject.body)).to eq(JSON.parse(staging_projects.to_json))
      end
    end
  end

  describe 'GET #show' do
    let(:source_package) { create(:package) }
    let(:target_package) { create(:package, name: 'target_package', project: factory) }
    let(:bs_request) do
      create(:bs_request_with_submit_action,
             target_project: factory.name,
             target_package: target_package.name,
             source_project: source_package.project.name,
             source_package: source_package.name)
    end
    let(:description) do
      <<-DESCRIPTION
        requests:
          - { id: #{bs_request.number} }
      DESCRIPTION
    end

    context 'with a existent factory_staging_project' do
      before do
        bs_request.update(state: 'declined')
        factory_staging_a.update(description: description)
      end

      context 'requesting html' do
        subject { get :show, params: { project: factory, project_name: 'A' } }

        it { expect(subject).to have_http_status(:success) }
        it { expect(subject).to render_template(:show) }
      end

      context 'requesting json' do
        subject { get :show, params: { project: factory, project_name: 'A' }, format: :json }

        it { is_expected.to have_http_status(:success) }
        it 'responds with a json representation of the staging project' do
          response = JSON.parse(subject.body)
          expect(response).to include(
            'name'              => 'openSUSE:Factory:Staging:A',
            'description'       => description,
            'obsolete_requests' => [JSON.parse(bs_request.to_json)],
            'overall_state'     => 'unacceptable'
          )
        end
      end
    end

    context 'with a non-existent factory_staging_project' do
      subject { get :show, params: { project: factory, project_name: 'B' } }

      it { expect(subject).to have_http_status(:found) }
      it { expect(subject).to redirect_to(root_path) }
    end
  end
end
