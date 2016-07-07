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
  let(:repo_for_user_home) { create(:repository, project: user.home_project) }

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

    context 'without nextstatus param' do
      before do
        get :show, project: apache_project
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'with nextstatus param' do
      before do
        get :show, { project: apache_project, nextstatus: 500 }
      end

      it { expect(response).to have_http_status(:internal_server_error) }
    end

    context 'without patchinfo' do
      before do
        get :show, project: apache_project
      end

      it { expect(assigns(:has_patchinfo)).to be_falsey }
    end

    context 'with patchinfo' do
      before do
        login admin_user
        # Avoid fetching from backend directly
        Directory.stubs(:hashed).returns(Xmlhash::XMLHash.new('entry' => {'name' => '_patchinfo'}))
        # Avoid writing to the backend
        Package.any_instance.stubs(:sources_changed).returns(nil)
        Patchinfo.new.create_patchinfo(apache_project.name, nil, comment: 'Fake comment', force: false)
        get :show, project: apache_project
      end

      it { expect(assigns(:has_patchinfo)).to be_truthy }
    end

    context 'with comments' do
      before do
        apache_project.comments << build(:comment_project, user: user)
        get :show, project: apache_project
      end

      it { expect(assigns(:comments)).to match_array(apache_project.comments) }
    end

    context 'with bugowners' do
      before do
        create(:relationship_project_user, role: Role.find_by_title('bugowner'), project: apache_project, user: user)
        get :show, project: apache_project
      end

      it { expect(assigns(:bugowners_mail)).to match_array([user.email]) }
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

  describe 'GET #buildresult' do
    it 'assigns the buildresult' do
      summary = Xmlhash::XMLHash.new({'statuscount' => {'code' => 'succeeded', 'count' => 1} })
      build_result  = { 'result' => Xmlhash::XMLHash.new({'repository' => 'openSUSE', 'arch' => 'x86_64', 'summary' => summary }) }
      Buildresult.stubs(:find_hashed).returns(Xmlhash::XMLHash.new(build_result))
      xhr :get, :buildresult, project: project_with_package
      expect(assigns(:buildresult)).to match_array([["openSUSE", [["x86_64", [[:succeeded, 1]]]]]])
    end
  end

  describe 'GET #delete_dialog' do
    it 'assigns only linking_projects' do
      apache2_project
      another_project.projects_linking_to << apache_project
      xhr :get, :delete_dialog, project: apache_project
      expect(assigns(:linking_projects)).to match_array([another_project.name])
    end
  end

  describe 'DELETE #destroy' do
    before do
      login user
    end

    context 'with check_weak_dependencies enabled' do
      before do
        Project.any_instance.stubs(:check_weak_dependencies?).returns(true)
      end

      context 'having a parent project' do
        before do
          subproject = create(:project, name: "#{user.home_project}:subproject")
          delete :destroy, project: subproject
        end

        it { expect(Project.count).to eq(1) }
        it { is_expected.to redirect_to(project_show_path(user.home_project)) }
        it { expect(flash[:notice]).to eq("Project was successfully removed.") }
      end

      context 'not having a parent project' do
        before do
          delete :destroy, project: user.home_project
        end

        it { expect(Project.count).to eq(0) }
        it { is_expected.to redirect_to(action: :index) }
        it { expect(flash[:notice]).to eq("Project was successfully removed.") }
      end
    end

    context 'with check_weak_dependencies disabled' do
      before do
        Project.any_instance.stubs(:check_weak_dependencies?).returns(false)
        delete :destroy, project: user.home_project
      end

      it { expect(Project.count).to eq(1) }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
      it { expect(flash[:notice]).to start_with("Project can't be removed:") }
    end
  end

  describe 'POST #update_target' do
    before do
      login user
    end

    context 'updating non existent repository' do
      it 'will raise a NoMethodError' do
        expect do
          post :update_target, project: user.home_project, repo: 'standard'
        end.to raise_error(NoMethodError)
      end
    end

    context 'updating the repository without architectures' do
      before do
        post :update_target, project: user.home_project, repo: repo_for_user_home.name
      end

      it { expect(repo_for_user_home.architectures.pluck(:name)).to be_empty }
      it { expect(assigns(:repository_arch_hash).to_a).to match_array([["armv7l", false], ['i586', false], ['x86_64', false]])}
      it { is_expected.to redirect_to(action: :repositories) }
      it { expect(flash[:notice]).to eq("Successfully updated repository") }
    end

    context 'updating the repository with architectures' do
      before do
        post :update_target, project: user.home_project, repo: repo_for_user_home.name, arch: {'i586' => true, 'x86_64' => true}
      end

      it { expect(repo_for_user_home.architectures.pluck(:name)).to match_array(['i586', 'x86_64']) }
      it { expect(Architecture.available.pluck(:name)).to match_array(["armv7l", "i586", "x86_64"]) }
      it { expect(assigns(:repository_arch_hash).to_a).to match_array([["armv7l", false], ['i586', true], ['x86_64', true]])}
      it { is_expected.to redirect_to(action: :repositories) }
      it { expect(flash[:notice]).to eq("Successfully updated repository") }
    end
  end

  describe 'GET #repositories' do
    before do
      get :repositories, project: apache_project
    end

    it { expect(assigns(:build).to_s).to eq(apache_project.get_flags('build').to_s) }
    it { expect(assigns(:debuginfo).to_s).to eq(apache_project.get_flags('debuginfo').to_s) }
    it { expect(assigns(:publish).to_s).to eq(apache_project.get_flags('publish').to_s) }
    it { expect(assigns(:useforbuild).to_s).to eq(apache_project.get_flags('useforbuild').to_s) }
    it { expect(assigns(:architectures)).to eq(apache_project.architectures.uniq) }
  end

  describe 'GET #repository_state' do
    context 'with a valid repository param' do
      before do
        get :repository_state, project: user.home_project, repository: repo_for_user_home.name
      end

      it { expect(assigns(:repocycles)).to be_a(Hash) }
      it { expect(assigns(:repository)).to eq(repo_for_user_home) }
      it { expect(assigns(:archs)).to match_array(repo_for_user_home.architectures.pluck(:name)) }
    end

    context 'with a non valid repository param' do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        get :repository_state, project: user.home_project, repository: 'non_valid_repo_name'
      end

      it { expect(assigns(:repocycles)).to be_a(Hash) }
      it { expect(assigns(:repository)).to be_falsey }
      it { is_expected.to redirect_to(:back) }
    end
  end

  describe 'GET #rebuild_time' do
    before do
      # To not ask backend for build status
      Project.any_instance.stubs(:number_of_build_problems).returns(0)
    end

    context 'with an invalid scheduler' do
      before do
        get :rebuild_time, project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64', scheduler: 'invalid_scheduler'
      end

      it { expect(flash[:error]).to eq('Invalid scheduler type, check mkdiststats docu - aehm, source') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'without build dependency info or jobs history' do
      before do
        BuilddepInfo.stubs(:find).returns(nil)
        Jobhistory.stubs(:find).returns(nil)
        get :rebuild_time, project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64'
      end

      it { expect(flash[:error]).to start_with('Could not collect infos about repository') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'normal flow' do
      before do
        BuilddepInfo.stubs(:find).returns([])
        Jobhistory.stubs(:find).returns([])
      end

      context 'with diststats generated' do
        before do
          path = Xmlhash::XMLHash.new({'package' => 'package_name' })
          longestpaths_xml = Xmlhash::XMLHash.new({ 'longestpath' => Xmlhash::XMLHash.new({'path' => path }) })
          Webui::ProjectController.any_instance.stubs(:call_diststats).returns(longestpaths_xml)
          get :rebuild_time, project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64'
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], [], ["package_name"]]) }
      end

      context 'with diststats not generated' do
        before do
          Webui::ProjectController.any_instance.stubs(:call_diststats).returns(nil)
          get :rebuild_time, project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64'
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], []]) }
      end
    end
  end

  describe 'GET #rebuild_time_png' do
    context 'with an invalid key' do
      before do
        get :rebuild_time_png, project: user.home_project, key: 'invalid_key'
      end

      it { expect(response.body).to be_empty }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end

    context 'with a valid key' do
      before do
        Rails.cache.write("rebuild-valid_key.png", "PNG Content")
        get :rebuild_time_png, project: user.home_project, key: 'valid_key'
      end

      it { expect(response.body).to eq("PNG Content") }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end
  end

  describe 'GET #requests' do
    before do
      get :requests, project: apache_project, type: 'my_type', state: 'my_state'
    end

    it { expect(assigns(:requests)).to eq(apache_project.open_requests) }
    it { expect(assigns(:default_request_type)).to eq('my_type') }
    it { expect(assigns(:default_request_state)).to eq('my_state') }
  end

  describe 'GET #create' do
    before do
      login user
      request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
    end

    shared_examples "a valid project saved" do |project|
      it { expect(flash[:notice]).to start_with("Project '#{project}' was created successfully") }
      it { is_expected.to redirect_to(project_show_path(project)) }
    end

    context "with a namespace called 'base'" do
      before do
        get :create, project: { name: 'my_project' }, ns: user.home_project_name
      end

      it { expect(assigns(:project).name).to eq("#{user.home_project_name}:my_project") }
      it_should_behave_like "a valid project saved", "home:tom:my_project"
    end

    context 'with a param called maintenance_project' do
      before do
        get :create, project: { name: 'my_project' }, ns: user.home_project_name, maintenance_project: true
      end

      it { expect(assigns(:project).kind).to eq('maintenance') }
      it_should_behave_like "a valid project saved", "home:tom:my_project"
    end

    context 'with a param that disables a flag' do
      shared_examples "a param that creates a disabled flag" do |param_name, flag_name|
        before do
          get :create, :project => { name: 'my_project' }, :ns => user.home_project_name, param_name.to_sym => true
        end

        it { expect(assigns(:project).flags.pluck(:flag)).to include(flag_name) }
        it { expect(assigns(:project).flags.find_by(flag: flag_name).status).to eq('disable') }
        it_should_behave_like "a valid project saved", "home:tom:my_project"
      end

      it_should_behave_like "a param that creates a disabled flag", :access_protection, 'access'
      it_should_behave_like "a param that creates a disabled flag", :source_protection, 'sourceaccess'
      it_should_behave_like "a param that creates a disabled flag", :disable_publishing, 'publish'
    end

    context 'with an invalid project data' do
      before do
        get :create, project: { name: 'my invalid project' }, ns: user.home_project_name
      end

      it { expect(flash[:error]).to start_with('Failed to save project') }
      it { is_expected.to redirect_to(:back) }
    end
  end

  describe 'PATCH #update' do
    before do
      login user
    end

    context "with valid data" do
      before do
        patch :update, id: user.home_project.id, project: { title: 'New Title' }
      end

      it { expect(assigns(:project).title).to eq('New Title') }
      it { expect(flash[:notice]).to eq("Project was successfully updated.") }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context "with no valid data" do
      before do
        patch :update, id: user.home_project.id, project: { name: 'non valid name' }
      end

      it { expect(flash[:error]).to eq("Failed to update project") }
      it { is_expected.to render_template("webui/project/edit") }
      it { expect(response).to have_http_status(:success) }
    end
  end

  describe 'POST #create_dod_repository' do
    before do
      login user
    end

    context "with an existing repository" do
      let(:existing_repository) { create(:repository) }

      before do
        xhr :post, :create_dod_repository, project: user.home_project, name: existing_repository.name,
                                           arch: Architecture.first.name, url: 'http://whatever.com',
                                           repotype: 'rpmmd'
      end

      it { expect(assigns(:error)).to start_with('Repository with name') }
      it { expect(response).to have_http_status(:success) }
    end

    context "with no valid repository type" do
      before do
        xhr :post, :create_dod_repository, project: user.home_project, name: 'NewRepo',
                                           arch: Architecture.first.name, url: 'http://whatever.com',
                                           repotype: 'invalid_repo_type'
      end

      it { expect(assigns(:error)).to start_with("Couldn't add repository:") }
      it { expect(response).to have_http_status(:success) }
    end

    context "with no valid repository Architecture" do
      before do
        xhr :post, :create_dod_repository, project: user.home_project, name: 'NewRepo',
                                           arch: 'non_existent_arch', url: 'http://whatever.com',
                                           repotype: 'rpmmd'
      end

      it { expect(assigns(:error)).to start_with("Couldn't add repository:") }
      it { expect(response).to have_http_status(:success) }
    end

    context "with valid repository data" do
      before do
        xhr :post, :create_dod_repository, project: user.home_project, name: 'NewRepo',
                                           arch: Architecture.first.name, url: 'http://whatever.com',
                                           repotype: 'rpmmd'
      end

      it { expect(assigns(:error)).to be_nil }
      it { expect(response).to have_http_status(:success) }
    end
  end

  describe 'POST #save_repository' do
    before do
      login user
    end

    context "with a no valid repository name" do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        post :save_repository, project: user.home_project, repository: '_not/valid/name'
      end

      it { expect(flash[:error]).to eq("Couldn't add repository: 'Name must not start with '_' or contain any of these characters ':/'") }
      it { is_expected.to redirect_to(:back) }
    end

    context "with a non valid target repository" do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        post :save_repository, project: user.home_project, repository: 'valid_name', target_project: another_project, target_repo: 'non_valid_repo'
      end

      it { expect(flash[:error]).to eq("Can not add repository: Repository 'non_valid_repo' not found in project '#{another_project.name}'.") }
      it { is_expected.to redirect_to(:back) }
    end

    context "with a valid repository but with a non valid architecture" do
      before do
        target_repo = create(:repository, project: another_project)
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        post :save_repository, project: user.home_project, repository: 'valid_name', architectures: ['non_existent_arch']
      end

      it { expect(flash[:error]).to start_with("Can not add repository: Repository ") }
      it { is_expected.to redirect_to(:back) }
    end

    context "with a valid repository" do
      before do
        target_repo = create(:repository, project: another_project)
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        post :save_repository, project: user.home_project, repository: 'valid_name', target_project: another_project, target_repo: target_repo.name,
                               architectures: ['i586']
      end

      it { expect(flash[:success]).to eq("Successfully added repository") }
      it { is_expected.to redirect_to(action: :repositories, project: user.home_project) }
      it { expect(user.home_project.repositories.find_by(name: 'valid_name').repository_architectures.count).to eq(1) }
    end
  end

  describe 'POST #save_distributions' do
    let(:another_project_repository) { create(:repository, project: another_project) }
    let(:target_repository) { create(:repository, project: openSUSE_project) }
    let(:distribution) do
      create(:distribution, reponame: another_project_repository.name,
                            project: openSUSE_project, repository: target_repository.name, architectures: ['i586'])
    end
    let(:distribution_without_target_repo) { create(:distribution, reponame: another_project_repository.name, project: openSUSE_project) }
    let(:create_distributions_same_repo) do
      create_list(:distribution, 2, reponame: another_project_repository.name, project: openSUSE_project, repository: target_repository.name)
    end
    let(:create_distributions_other_reponame) { create_list(:distribution, 2, reponame: 'another_repon_name') }

    before do
      login user
    end

    context "without any distributions passed" do
      before do
        post :save_distributions, project: user.home_project
      end

      it { expect(flash[:success]).to eq("Successfully added repositories") }
      it { is_expected.to redirect_to(action: :repositories, project: user.home_project) }
      it { expect(assigns(:project).repositories.count).to eq(0) }
    end

    context "with a distribution but without target repository" do
      it "Raises an ActiveRecord::RecordNotFound exception" do
        expect do
          post :save_distributions, project: user.home_project,
                                    distributions: [distribution_without_target_repo.reponame]
        end.to raise_error ActiveRecord::RecordNotFound
      end
    end

    context "with a distribution properly set" do
      before do
        create_distributions_other_reponame
        post :save_distributions, project: user.home_project, distributions: [distribution.reponame]
      end

      it { expect(flash[:success]).to eq("Successfully added repositories") }
      it { is_expected.to redirect_to(action: :repositories, project: user.home_project) }
      it { expect(assigns(:project).repositories.count).to eq(1) }
      it { expect(assigns(:project).repositories.first.name).to eq(distribution.reponame) }
    end

    context "with a distribution called images" do
      before do
        Project.any_instance.stubs(:prepend_kiwi_config).returns(true)
        post :save_distributions, project: user.home_project, images: true
      end

      it { expect(flash[:success]).to eq("Successfully added repositories") }
      it { is_expected.to redirect_to(action: :repositories, project: user.home_project) }
      it { expect(assigns(:project).repositories.count).to eq(1) }
      it { expect(assigns(:project).repositories.first.name).to eq('images') }
      it { expect(assigns(:project).repositories.first.repository_architectures.count).to eq(Architecture.available.count) }
    end
  end
end
