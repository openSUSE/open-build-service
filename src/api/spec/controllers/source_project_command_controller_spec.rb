RSpec.describe SourceProjectCommandController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  before do
    login user
  end

  describe 'POST #project_command' do
    context 'when cmd=createkey' do
      before do
        allow(Backend::Api::Sources::Project).to receive(:createkey).and_return('<status code="ok"/>')
        post :project_command,
             params: { project: project.name, cmd: 'createkey', comment: 'create', keyalgo: 'rsa@4096', days: 800, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it do
        expect(Backend::Api::Sources::Project).to have_received(:createkey).with(
          project.name,
          hash_including(user: user.login, comment: 'create', keyalgo: 'rsa@4096', days: '800')
        )
      end
    end

    context 'when cmd=preparekey' do
      before do
        allow(Backend::Api::Sources::Project).to receive(:preparekey).and_return('<status code="ok"/>')
        post :project_command,
             params: { project: project.name, cmd: 'preparekey', comment: 'prepare', keyalgo: 'rsa@4096', days: 800, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it do
        expect(Backend::Api::Sources::Project).to have_received(:preparekey).with(
          project.name,
          hash_including(user: user.login, comment: 'prepare', keyalgo: 'rsa@4096', days: '800')
        )
      end
    end

    context 'when cmd=activatekey' do
      before do
        allow(Backend::Api::Sources::Project).to receive(:activatekey).and_return('<status code="ok"/>')
        post :project_command,
             params: { project: project.name, cmd: 'activatekey', comment: 'activate', format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it do
        expect(Backend::Api::Sources::Project).to have_received(:activatekey).with(
          project.name,
          hash_including(user: user.login, comment: 'activate')
        )
      end
    end
  end
end
