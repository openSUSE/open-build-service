RSpec.describe Webui::WebuiController do
  # The webui controller is an abstract controller
  # therefore we need an anoynmous rspec controller
  # https://www.relishapp.com/rspec/rspec-rails/docs/controller-specs/anonymous-controller
  controller do
    before_action :require_admin, only: :new
    before_action :require_login, only: :show
    before_action :set_project, only: %i[edit create update]
    before_action :set_package, only: :create
    before_action :set_optional_package, only: :update

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

    def update
      render plain: 'anonymous controller - set_optional_package'
    end
  end

  describe 'require_admin before filter' do
    it 'redirects to main page for non privileged user' do
      login(create(:confirmed_user, login: 'confirmed_user'))
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
      expect(flash[:error]).to eq('Authentication Required')
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

    context 'with a package that is missing from a project linking to a remote project' do
      let(:project) { create(:project, link_to: 'openSUSE.org:home:hans') }

      it 'redirects back' do
        from project_show_path(project: project)
        get :create, params: { project: project, package: 'invalid' }
        expect(flash[:error]).to eq("Package not found: #{project.name}/invalid")
        expect(response).to redirect_to project_show_url(project: project)
      end

      it 'does not assign a package' do
        get :create, params: { project: project, package: 'invalid' }
        expect(assigns(:package)).to be_nil
      end
    end

    context 'with a package that is missing from a project managed through scmsync' do
      let(:project) { create(:project, scmsync: 'https://src.opensuse.org/pool/_ObsPrj.git') }

      it 'redirects to the project' do
        get :create, params: { project: project, package: 'invalid' }
        expect(flash[:error]).to eq("The project #{project.name} is configured through scmsync. This is not supported by the OBS frontend")
        expect(response).to redirect_to project_show_path(project)
      end

      it 'does not assign a package' do
        get :create, params: { project: project, package: 'invalid' }
        expect(assigns(:package)).to be_nil
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

  describe 'set_optional_package before filter' do
    let(:project) { create(:project, scmsync: 'https://src.opensuse.org/pool/_ObsPrj.git') }

    context 'with a package that is missing from a project managed through scmsync' do
      it 'renders the action' do
        get :update, params: { id: 1, project: project, package: 'only_in_the_backend' }
        expect(response).to have_http_status(:success)
        expect(flash[:error]).to be_nil
      end

      it 'leaves the package unassigned but keeps its name' do
        get :update, params: { id: 1, project: project, package: 'only_in_the_backend' }
        expect(assigns(:package)).to be_nil
        expect(assigns(:package_name)).to eq('only_in_the_backend')
      end
    end

    context 'with a package that is missing from a project not managed through scmsync' do
      let(:project) { create(:project) }

      it 'still refuses to leave the package unassigned' do
        from project_show_path(project: project)
        get :update, params: { id: 1, project: project, package: 'invalid' }
        expect(flash[:error]).to eq("Package not found: #{project.name}/invalid")
        expect(response).to redirect_to project_show_url(project: project)
      end
    end

    context 'with a package that is missing from a project linking to a remote project' do
      let(:project) { create(:project, link_to: 'openSUSE.org:home:hans') }

      it 'still refuses to leave the package unassigned' do
        from project_show_path(project: project)
        get :update, params: { id: 1, project: project, package: 'invalid' }
        expect(flash[:error]).to eq("Package not found: #{project.name}/invalid")
        expect(response).to redirect_to project_show_url(project: project)
      end
    end

    context 'with valid package parameter' do
      let(:project) { create(:project) }
      let(:package) { create(:package, project: project) }

      it 'sets the correct package' do
        get :update, params: { id: 1, project: project, package: package }
        expect(assigns(:package)).to eq(package)
      end
    end
  end
end
