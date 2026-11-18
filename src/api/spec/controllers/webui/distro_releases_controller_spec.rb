RSpec.describe Webui::DistroReleasesController do
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }
  let!(:distro) { create(:distro, vendor: vendor, name: 'Leap') }

  before do
    Flipper.enable(:enhanced_distribution_support)
  end

  it { is_expected.to use_after_action(:verify_authorized) }

  describe 'POST #preview_description' do
    before do
      login user
      post :preview_description, params: { project_name: project.name, distro_name: distro.name, distro_release: { description: '**bold**' } },
                                 format: :json
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response.parsed_body['markdown']).to include('<strong>bold</strong>') }
  end

  describe 'GET #show' do
    let(:repository) { create(:repository, project: project, name: '16.0') }
    let!(:distro_release) do
      create(:distro_release, distro: distro, name: '16.0', repositories: [repository], architectures: [Architecture.find_by_name('x86_64')])
    end
    let!(:package_b) { create(:package, name: 'bash', project: project) }
    let!(:package_a) { create(:package, name: 'avahi', project: project) }

    before do
      login user
      get :show, params: { project_name: project.name, distro_name: distro.name, name: distro_release.name }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(assigns(:packages).map(&:name)).to eq(%w[avahi bash]) }

    context 'with a page size' do
      before do
        get :show, params: { project_name: project.name, distro_name: distro.name, name: distro_release.name, page_size: 1, page: 2 }
      end

      it { expect(assigns(:packages).map(&:name)).to eq(%w[bash]) }
    end
  end
end
