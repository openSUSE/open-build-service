RSpec.describe SourceProjectController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  before do
    login user
  end

  describe 'GET #show_pubkeys' do
    let(:pubkeys) { "pubkey-a\npubkey-b\n" }

    before do
      allow(Backend::Api::Sources::Project).to receive(:pubkeys).and_return(pubkeys)
      get :show_pubkeys, params: { project: project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(response.body).to eq(pubkeys) }
    it { expect(Backend::Api::Sources::Project).to have_received(:pubkeys).with(project.name) }
  end
end
