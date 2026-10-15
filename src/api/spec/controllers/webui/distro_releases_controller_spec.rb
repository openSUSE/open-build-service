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
end
