require 'rails_helper'

RSpec.describe Webui::ProjectController, vcr: true do
  let(:user) { create(:confirmed_user, login: "tom") }
  let(:admin_user) { create(:admin_user, login: "admin") }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }
  let(:apache2_project) { create(:project, name: 'Apache2') }
  let(:openSUSE_project) { create(:project, name: 'openSUSE') }
  let(:apache_maintenance_incident_project) { create(:maintenance_incident_project, name: 'ApacheMI') }
  let(:home_moi_project) { create(:project, name: 'home:moi') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project') }
  let(:project_with_package) { create(:project_with_package, name: 'NewProject', package_name: 'PackageExample') }

  describe 'CSRF protection' do
    before do
      # Needed because Rails disables it in test mode by default
      ActionController::Base.allow_forgery_protection = true

      login user
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it 'will protect forms without authenticity token' do
      expect { post :save_person, project: 'home:tom' }.to raise_error ActionController::InvalidAuthenticityToken
    end
  end

  describe 'GET #index' do
    context 'showing all projects' do
      before do
        home_moi_project
        another_project
        get :index, { show_all: true}
      end

      it { expect(assigns(:projects).length).to eq(2) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing not home projects' do
      before do
        home_moi_project
        another_project
        get :index, { show_all: false}
      end

      it { expect(assigns(:projects).length).to eq(1) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing projects being a spider bot' do
      before do
        request.env['HTTP_OBS_SPIDER'] = true
        get :index
      end

      it { is_expected.to render_template("webui/project/list_simple") }
    end
  end

  describe 'PATCH #update' do
    let(:project) { user.home_project }

    context "with valid parameters" do
      before do
        login user
        patch :update, id: project.id, project: { description: "My projects description", title: "My projects title" }
        project.reload
      end

      it { expect(response).to redirect_to( project_show_path(project)) }
      it { expect(flash[:notice]).to eq "Project was successfully updated." }
      it { expect(project.title).to eq "My projects title" }
      it { expect(project.description).to eq "My projects description" }
    end

    context "with invalid data" do
      before do
        login user
        patch :update, id: project.id, project: { description: "My projects description", title: "My projects title"*200 }
        project.reload
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(flash[:error]).to eq "Failed to update project" }
      it { expect(project.title).to be nil }
      it { expect(project.description).to be nil }
    end
  end

  describe 'GET #autocomplete_projects' do
    before do
      apache_project
      apache2_project
      openSUSE_project
      apache_maintenance_incident_project
    end

    context 'without search term' do
      before do
        get :autocomplete_projects
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly(apache_project.name, apache2_project.name, openSUSE_project.name) }
      it { expect(@json_response).not_to include(apache_maintenance_incident_project.name) }
    end

    context 'with search term' do
      before do
        get :autocomplete_projects, term: 'Apache'
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly(apache_project.name, apache2_project.name) }
      it { expect(@json_response).not_to include(apache_maintenance_incident_project.name) }
      it { expect(@json_response).not_to include(openSUSE_project.name) }
    end
  end

  describe 'GET #autocomplete_incidents' do
    before do
      apache_project
      apache_maintenance_incident_project
      get :autocomplete_incidents, term: 'Apache'
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response).to contain_exactly(apache_maintenance_incident_project.name) }
    it { expect(@json_response).not_to include(apache_project.name) }
  end

  describe 'GET #autocomplete_packages' do
    before do
      create(:package, name: 'Apache_Package', project: apache_project)
      create(:package, name: 'Apache2_Package', project: apache_project)
      create(:package, name: 'Apache_Package_Another_Project', project: another_project)
    end

    context 'without search term' do
      before do
        get :autocomplete_packages, project: apache_project
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache_Package', 'Apache2_Package') }
      it { expect(@json_response).not_to include('Apache_Package_Another_Project') }
    end

    context 'with search term' do
      before do
        get :autocomplete_packages, { project: apache_project, term: 'Apache2' }
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache2_Package') }
      it { expect(@json_response).not_to include('Apache_Package') }
      it { expect(@json_response).not_to include('Apache_Package_Another_Project') }
    end
  end

  describe 'GET #autocomplete_repositories' do
    before do
      @repositories = create_list(:repository, 5, { project: apache_project })
      get :autocomplete_repositories, project: apache_project
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response).to match_array(@repositories.map(&:name)) }
  end

  describe 'GET #users' do
    before do
      create(:relationship_project_user, project: apache_project, user: create(:confirmed_user))
      create(:relationship_project_user, project: apache_project, user: create(:confirmed_user))
      create(:relationship_project_group, project: apache_project, group: create(:group))

      create(:relationship_project_user, project: another_project, user: create(:confirmed_user))
      create(:relationship_project_group, project: another_project, group: create(:group))
      get :users, project: apache_project
    end

    it { expect(assigns(:users)).to match_array(apache_project.users) }
    it { expect(assigns(:groups)).to match_array(apache_project.groups) }
    it { expect(assigns(:roles)).to match_array(Role.local_roles) }
  end

  describe 'GET #subprojects' do
    before do
      apache_project
      @project = create(:project, name: 'Apache:Apache2')
      create(:project, name: 'Apache:Apache2:TestSubproject')
      create(:project, name: 'Apache:Apache2:TestSubproject2')
      another_project
      get :subprojects, project: @project
    end

    it { expect(assigns(:subprojects)).to match_array(@project.subprojects) }
    it { expect(assigns(:parentprojects)).to match_array(@project.ancestors) }
  end

  describe 'GET #new' do
    before do
      login user
      get :new, name: 'ProjectName'
    end

    it { expect(assigns(:project)).to be_a(Project) }
    it { expect(assigns(:project).name).to eq('ProjectName') }
  end

  describe 'GET #show' do
    before do
      # To not ask backend for build status
      Project.any_instance.stubs(:number_of_build_problems).returns(0)
    end

    it 'without nextstatus param' do
      get :show, project: apache_project
      expect(response).to have_http_status(:ok)
    end

    it 'with nextstatus param' do
      get :show, { project: apache_project, nextstatus: 500 }
      expect(response).to have_http_status(:internal_server_error)
    end

    it 'without patchinfo' do
      get :show, project: apache_project
      expect(assigns(:has_patchinfo)).to be_falsey
    end

    it 'with patchinfo' do
      login admin_user
      # Avoid fetching from backend directly
      Directory.stubs(:hashed).returns(Xmlhash::XMLHash.new('entry' => {'name' => '_patchinfo'}))
      # Avoid writing to the backend
      Package.any_instance.stubs(:sources_changed).returns(nil)
      Patchinfo.new.create_patchinfo(apache_project.name, nil, comment: 'Fake comment', force: false)
      get :show, project: apache_project
      expect(assigns(:has_patchinfo)).to be_truthy
    end

    it 'with comments' do
      apache_project.comments << build(:comment_project, user: user)
      get :show, project: apache_project
      expect(assigns(:comments)).to match_array(apache_project.comments)
    end

    it 'with bugowners' do
      create(:relationship_project_user, role: Role.find_by_title('bugowner'), project: apache_project, user: user)
      get :show, project: apache_project
      expect(assigns(:bugowners_mail)).to match_array([user.email])
    end

    context 'without bugowners' do
      before do
        get :show, project: apache_project
      end

      it { expect(assigns(:bugowners_mail)).to be_a(Array) }
      it { expect(assigns(:bugowners_mail)).to be_empty }
    end
  end

  describe 'GET #new_package_branch' do
    it 'branches the package' do
      login user
      @remote_projects_created = create_list(:remote_project, 3)
      get :new_package_branch, project: apache_project
      expect(assigns(:remote_projects)).to match_array(@remote_projects_created.map {|r| [r.id, r.name, r.title]})
    end
  end

  describe 'GET #new_incident' do
    before do
      login admin_user
    end

    context 'with a Maintenance project' do
      # This is needed because we can't see local variables of the controller action
      let(:new_maintenance_incident_project) { Project.maintenance_incident.first }

      before do
        get :new_incident, ns: maintenance_project
      end

      it { is_expected.to redirect_to(project_show_path(project: new_maintenance_incident_project.name)) }
      it { expect(flash[:success]).to start_with("Created maintenance incident project #{new_maintenance_incident_project.name}") }
    end

    context 'without a Maintenance project' do
      before do
        get :new_incident, ns: apache_project
      end

      it { is_expected.to redirect_to(project_show_path(project: apache_project)) }
      it { expect(flash[:error]).to eq('Incident projects shall only create below maintenance projects.') }
    end
  end

  describe 'GET #linking_projects' do
    before do
      login user
      apache2_project
      another_project.projects_linking_to << apache_project
      xhr :get, :linking_projects, project: apache_project
    end

    it { expect(Project.count).to eq(4) }
    it { expect(assigns(:linking_projects)).to match_array([another_project.name]) }
  end

  describe 'GET #add_repository_from_default_list' do
    context 'with some distributions' do
      it 'shows repositories from default list' do
        login user
        create_list(:distribution, 4, vendor: 'vendor1')
        create_list(:distribution, 2, vendor: 'vendor2')
        get :add_repository_from_default_list, project: apache_project
        expect(assigns(:distributions).length).to eq(2)
      end
    end

    context 'without any distribution and being normal user' do
      before do
        login user
        get :add_repository_from_default_list, project: apache_project
      end

      it { is_expected.to redirect_to(controller: 'project', action: 'add_repository', project: apache_project) }
      it { expect(assigns(:distributions)).to be_empty }
    end

    context 'without any distribution and being admin user' do
      before do
        login admin_user
        get :add_repository_from_default_list, project: apache_project
      end

      it { is_expected.to redirect_to(configuration_interconnect_path) }
      it { expect(flash[:alert]).to eq('There are no distributions configured. Maybe you want to connect to one of the public OBS instances?') }
      it { expect(assigns(:distributions)).to be_empty }
    end
  end

  describe 'GET #add_person' do
    it 'assigns the local roles' do
      login user
      get :add_person, project: user.home_project
      expect(assigns(:roles)).to match_array(Role.local_roles)
    end
  end

  describe 'GET #add_group' do
    it 'assigns the local roles' do
      login user
      get :add_group, project: user.home_project
      expect(assigns(:roles)).to match_array(Role.local_roles)
    end
  end

  describe 'POST #save_repository' do
    it 'does not save invalid repositories' do
      login user
      expect {
        get :save_repository, project: user.home_project, repository: "_invalid"
      }.to_not change(Repository, :count)
      expect(flash[:error]).to eq("Couldn't add repository: 'Name must not start with '_' or contain any of these characters ':/'")
    end
  end
end
