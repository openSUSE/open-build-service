RSpec.describe BuildController do
  render_views

  let(:user) { create(:confirmed_user) }
  let(:project_name) { 'home:build_controller' }
  let(:project) { instance_double(Project) }

  before do
    login user
  end

  describe 'GET #result' do
    subject(:perform_request) { get :result, params: { project: project_name, lastsuccess: lastsuccess, format: :xml } }

    context 'with an invalid lastsuccess value' do
      let(:lastsuccess) { 'yes' }

      before do
        get :result, params: { project: project_name, lastsuccess: lastsuccess, pathproject: 'kde4', package: 'TestPack', format: :xml }
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(response.headers['X-Opensuse-Errorcode']).to eq('invalid_parameter') }
    end

    context 'with a falsy lastsuccess value' do
      %w[0 false].each do |value|
        let(:lastsuccess) { value }
        let(:backend_paths) { [] }

        before do
          allow(Project).to receive(:get_by_name).with(project_name).and_return(project)
          allow(controller).to receive(:pass_to_backend) do |path|
            backend_paths << path
            controller.head :ok
          end

          perform_request
        end

        it("falls back to the regular build result listing for #{value.inspect}") { expect(controller).to have_received(:pass_to_backend) }
        it { expect(backend_paths.first).not_to include('lastsuccess') }
        it { expect(response).to have_http_status(:success) }
      end
    end

    context 'with a truthy lastsuccess value' do
      ['', '1', 'true'].each do |value|
        let(:lastsuccess) { value }

        before do
          allow(controller).to receive(:result_lastsuccess) { controller.head :ok }

          perform_request
        end

        it("invokes the lastsuccess result path for #{value.inspect}") { expect(controller).to have_received(:result_lastsuccess) }
        it { expect(response).to have_http_status(:success) }
      end
    end
  end
end
