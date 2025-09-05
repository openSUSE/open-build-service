RSpec.describe Webui::WebuiController do
  # The webui controller is an abstract controller
  # therefore we need an anoynmous rspec controller
  # https://www.relishapp.com/rspec/rspec-rails/docs/controller-specs/anonymous-controller
  controller do
    before_action :require_admin, only: :new
    before_action :require_login, only: :show
    before_action :set_project, only: %i[edit create]
    before_action :set_package, only: :create
    before_action :check_anonymous, only: :index

    def index
      render plain: 'anonymous controller  - check_anonymous'
    end

    # RSpec anonymous controller only support RESTful routes
    # http://stackoverflow.com/questions/7027518/no-route-matches-rspecs-anonymous-controller
    def new
      render plain: 'anonymous controller - requires_admin_privileges'
    end

    def show
      render plain: 'anonymous controller - requires_login'
    end

    def edit
      render plain: 'anonymous controller - set_project'
    end

    def create
      render plain: 'anonymous controller - set_package'
    end
  end

  describe 'require_admin before filter' do
    it 'redirects to main page for non privileged user' do
      sign_in(create(:confirmed_user, login: 'confirmed_user'))
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Requires admin privileges')
    end

    it 'redirects to main page for nobody user' do
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Requires admin privileges')
    end

    it 'for admin' do
      login(create(:admin_user, login: 'admin_user'))
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'require_login before filter' do
    it 'redirects to main page for new users' do
      get :show, params: { id: 1 }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:error]).to eq('Please login to access the resource')
    end

    it 'does not redirect for a confirmed user' do
      login(create(:confirmed_user, login: 'eisendieter'))
      get :show, params: { id: 1 }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'set_project before filter' do
    context 'with invalid project parameter' do
      it 'redirects back' do
        from projects_path
        get :edit, params: { id: 1, project: 'invalid' }
        expect(flash[:error]).to eq('Project not found: invalid')
        expect(response).to redirect_to projects_url
      end
    end

    context 'with valid project parameter' do
      let(:project) { create(:project) }

      it 'sets the correct project' do
        get :edit, params: { id: 1, project: project.name }
        expect(assigns(:project)).to eq(project)
      end
    end
  end

  describe 'set_package before filter' do
    let(:project) { create(:project) }

    context 'with invalid package parameter' do
      it 'redirects back' do
        from project_show_path(project: project)
        get :create, params: { project: project, package: 'invalid' }
        expect(flash[:error]).to eq("Package not found: #{project.name}/invalid")
        expect(response).to redirect_to project_show_url(project: project)
      end
    end

    context 'with valid package parameter' do
      let(:package) { create(:package, project: project) }

      it 'sets the correct project' do
        get :create, params: { project: project, package: package }
        expect(assigns(:package)).to eq(package)
      end
    end
  end

  describe 'check_anonymous before filter' do
    subject { get :index }

    before do
      allow(Configuration).to receive(:anonymous).and_return(false)
    end

    context 'with proxy_auth_mode enabled' do
      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
        stub_const('CONFIG', { proxy_auth_login_page: '/', proxy_auth_logout_page: '/', proxy_auth_mode: :mellon }.with_indifferent_access)
      end

      it { is_expected.to redirect_to('/?ReturnTo=%2Fwebui%2Fwebui') }
    end

    context 'with proxy_auth_mode disabled' do
      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(false)
      end

      it { is_expected.to redirect_to(root_path) }
    end
  end
end
