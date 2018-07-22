require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::ObsFactory::DistributionsController, type: :controller do
  let(:factory) { create(:project, name: 'openSUSE:Factory') }
  let!(:factory_staging_a) { create(:project, name: 'openSUSE:Factory:Staging:A', description: 'Factory staging project A') }
  let!(:factory_ring_bootstrap) { create(:project, name: 'openSUSE:Factory:Rings:0-Bootstrap', description: 'Factory ring project') }
  let(:target_package) { create(:package, name: 'target_package', project: factory) }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }

  describe 'GET #show' do
    include_context 'a opensuse product'

    # Mocks for source_version and totest_version that are called in @versions
    let(:mock_totest_version) { "#{CONFIG['source_url']}/build/#{factory}:ToTest/images/local/000product:openSUSE-cd-mini-x86_64" }
    let(:mock_source_version) { "#{CONFIG['source_url']}/source/#{factory}/000product/openSUSE.product" }

    before do
      stub_request(:get, mock_totest_version).and_return(body: '')
      stub_request(:get, mock_source_version).and_return(body: opensuse_product)
      allow(::ObsFactory::OpenqaJob).to receive(:find_all_by).and_return([:fake, :content])

      get :show, params: { project: factory.name }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response).to render_template(:show) }

    it { expect(assigns(:staging_projects).first.project).to eq(factory_staging_a) }

    it { expect(assigns(:versions)[:source]).to eq(assigns(:distribution).source_version) }
    it { expect(assigns(:versions)[:totest]).to eq(assigns(:distribution).totest_version) }
    it { expect(assigns(:versions)[:published]).to eq(assigns(:distribution).published_version) }

    it { expect(assigns(:ring_prjs).first.project).to eq(factory_ring_bootstrap) }
    it { expect(assigns(:standard).nickname).to eq('standard') }
    it { expect(assigns(:images).nickname).to eq('images') }
    it { expect(assigns(:live)).to be_nil }
    it { expect(assigns(:openqa_jobs)).to eq([:fake, :content]) }

    context 'calculate_reviews' do
      let!(:repo_checker_user) { create(:user, login: 'repo-checker') }
      let!(:create_groups_and_reviews) do
        ['opensuse-review-team', 'factory-auto', 'legal-auto', 'legal-team'].each do |title|
          create(:group, title: title)
          create(:review_bs_request_by_group,
                 reviewer: title,
                 target_project: factory.name,
                 target_package: target_package.name,
                 source_project: source_package.project.name,
                 source_package: source_package.name)
        end
        create(:review_bs_request,
               reviewer: 'repo-checker',
               target_project: factory.name,
               target_package: target_package.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end

      before do
        get :show, params: { project: factory.name }
      end

      it { expect(assigns(:reviews)[:review_team]).to eq(1) }
      it { expect(assigns(:reviews)[:factory_auto]).to eq(1) }
      it { expect(assigns(:reviews)[:legal_auto]).to eq(1) }
      it { expect(assigns(:reviews)[:legal_team]).to eq(1) }
      it { expect(assigns(:reviews)[:repo_checker]).to eq(1) }
    end

    it { expect(assigns(:project)).to eq(factory) }

    context 'with a live_project' do
      let!(:factory_live) { create(:project, name: 'openSUSE:Factory:Live') }

      before do
        get :show, params: { project: factory.name }
      end

      it { expect(assigns(:live).name).to eq('openSUSE:Factory:Live') }
    end
  end
end
