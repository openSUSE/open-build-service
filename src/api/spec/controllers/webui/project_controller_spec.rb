require 'rails_helper'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::ProjectController, vcr: true do
  let(:user) { create(:confirmed_user, login: "tom") }
  let(:admin_user) { create(:admin_user, login: "admin") }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }
  let(:apache2_project) { create(:project, name: 'Apache2') }
  let(:openSUSE_project) { create(:project, name: 'openSUSE') }
  let(:apache_maintenance_incident_project) { create(:maintenance_incident_project, name: 'ApacheMI', maintenance_project: nil) }
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
      expect { post :save_person, params: { project: user.home_project } }.to raise_error ActionController::InvalidAuthenticityToken
    end
  end

  describe 'GET #index' do
    context 'showing all projects' do
      before do
        home_moi_project
        another_project
        get :index, params: { show_all: true}
      end

      it { expect(assigns(:projects).length).to eq(2) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing not home projects' do
      before do
        home_moi_project
        another_project
        get :index, params: { show_all: false}
      end

      it { expect(assigns(:projects).length).to eq(1) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing projects being a spider bot' do
      before do
        # be a fake google bot
        request.env['HTTP_USER_AGENT'] = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
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
        patch :update, params: { id: project.id, project: { description: "My projects description", title: "My projects title" } }
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
        patch :update, params: { id: project.id, project: { description: "My projects description", title: "My projects title"*200 } }
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
        get :autocomplete_projects, params: { term: 'Apache' }
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
      get :autocomplete_incidents, params: { term: 'Apache' }
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
        get :autocomplete_packages, params: { project: apache_project }
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache_Package', 'Apache2_Package') }
      it { expect(@json_response).not_to include('Apache_Package_Another_Project') }
    end

    context 'with search term' do
      before do
        get :autocomplete_packages, params: { project: apache_project, term: 'Apache2' }
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
      get :autocomplete_repositories, params: { project: apache_project }
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
      get :users, params: { project: apache_project }
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
      get :subprojects, params: { project: @project }
    end

    it { expect(assigns(:subprojects)).to match_array(@project.subprojects) }
    it { expect(assigns(:parentprojects)).to match_array(@project.ancestors) }
  end

  describe 'GET #new' do
    before do
      login user
      get :new, params: { name: 'ProjectName' }
    end

    it { expect(assigns(:project)).to be_a(Project) }
    it { expect(assigns(:project).name).to eq('ProjectName') }
  end

  describe 'GET #show' do
    before do
      # To not ask backend for build status
      allow_any_instance_of(Project).to receive(:number_of_build_problems).and_return(0)
    end

    context 'without nextstatus param' do
      before do
        get :show, params: { project: apache_project }
      end

      it { expect(response).to have_http_status(:ok) }
    end

    context 'with nextstatus param' do
      before do
        get :show, params: { project: apache_project, nextstatus: 500 }
      end

      it { expect(response).to have_http_status(:internal_server_error) }
    end

    context 'without patchinfo' do
      before do
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:has_patchinfo)).to be_falsey }
    end

    context 'with patchinfo' do
      before do
        login admin_user
        # Avoid fetching from backend directly
        allow(Directory).to receive(:hashed).and_return(Xmlhash::XMLHash.new('entry' => {'name' => '_patchinfo'}))
        # Avoid writing to the backend
        allow_any_instance_of(Package).to receive(:sources_changed)
        Patchinfo.new.create_patchinfo(apache_project.name, nil, comment: 'Fake comment', force: false)
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:has_patchinfo)).to be_truthy }
    end

    context 'with comments' do
      before do
        apache_project.comments << build(:comment_project, user: user)
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:comments)).to match_array(apache_project.comments) }
    end

    context 'with bugowners' do
      before do
        create(:relationship_project_user, role: Role.find_by_title('bugowner'), project: apache_project, user: user)
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:bugowners_mail)).to match_array([user.email]) }
    end

    context 'without bugowners' do
      before do
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:bugowners_mail)).to be_a(Array) }
      it { expect(assigns(:bugowners_mail)).to be_empty }
    end
  end

  describe 'GET #new_package_branch' do
    it 'branches the package' do
      login user
      @remote_projects_created = create_list(:remote_project, 3)
      get :new_package_branch, params: { project: apache_project }
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
        get :new_incident, params: { ns: maintenance_project }
      end

      it { is_expected.to redirect_to(project_show_path(project: new_maintenance_incident_project.name)) }
      it { expect(flash[:success]).to start_with("Created maintenance incident project #{new_maintenance_incident_project.name}") }
    end

    context 'without a Maintenance project' do
      before do
        get :new_incident, params: { ns: apache_project }
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
      get :linking_projects, params: { project: apache_project }, xhr: true
    end

    it { expect(Project.count).to eq(4) }
    it { expect(assigns(:linking_projects)).to match_array([another_project.name]) }
  end

  describe 'GET #add_person' do
    it 'assigns the local roles' do
      login user
      get :add_person, params: { project: user.home_project }
      expect(assigns(:roles)).to match_array(Role.local_roles)
    end
  end

  describe 'GET #add_group' do
    it 'assigns the local roles' do
      login user
      get :add_group, params: { project: user.home_project }
      expect(assigns(:roles)).to match_array(Role.local_roles)
    end
  end

  describe 'GET #buildresult' do
    it 'assigns the buildresult' do
      summary = Xmlhash::XMLHash.new({'statuscount' => {'code' => 'succeeded', 'count' => 1} })
      build_result = { 'result' => Xmlhash::XMLHash.new({'repository' => 'openSUSE', 'arch' => 'x86_64', 'summary' => summary }) }
      allow(Buildresult).to receive(:find_hashed).and_return(Xmlhash::XMLHash.new(build_result))
      get :buildresult, params: { project: project_with_package }, xhr: true
      expect(assigns(:buildresult)).to match_array([["openSUSE", [["x86_64", [[:succeeded, 1]]]]]])
    end
  end

  describe 'GET #delete_dialog' do
    it 'assigns only linking_projects' do
      apache2_project
      another_project.projects_linking_to << apache_project
      get :delete_dialog, params: { project: apache_project }, xhr: true
      expect(assigns(:linking_projects)).to match_array([another_project.name])
    end
  end

  describe 'DELETE #destroy' do
    before do
      login user
    end

    context 'with check_weak_dependencies enabled' do
      before do
        allow_any_instance_of(Project).to receive(:check_weak_dependencies?).and_return(true)
      end

      context 'having a parent project' do
        before do
          subproject = create(:project, name: "#{user.home_project}:subproject")
          delete :destroy, params: { project: subproject }
        end

        it { expect(Project.count).to eq(1) }
        it { is_expected.to redirect_to(project_show_path(user.home_project)) }
        it { expect(flash[:notice]).to eq("Project was successfully removed.") }
      end

      context 'not having a parent project' do
        before do
          delete :destroy, params: { project: user.home_project }
        end

        it { expect(Project.count).to eq(0) }
        it { is_expected.to redirect_to(action: :index) }
        it { expect(flash[:notice]).to eq("Project was successfully removed.") }
      end
    end

    context 'with check_weak_dependencies disabled' do
      before do
        allow_any_instance_of(Project).to receive(:check_weak_dependencies?).and_return(false)
        delete :destroy, params: { project: user.home_project }
      end

      it { expect(Project.count).to eq(1) }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
      it { expect(flash[:notice]).to start_with("Project can't be removed:") }
    end
  end

  describe 'GET #rebuild_time' do
    before do
      # To not ask backend for build status
      allow_any_instance_of(Project).to receive(:number_of_build_problems).and_return(0)
    end

    context 'with an invalid scheduler' do
      before do
        get :rebuild_time, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64', scheduler: 'invalid_scheduler' }
      end

      it { expect(flash[:error]).to eq('Invalid scheduler type, check mkdiststats docu - aehm, source') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'without build dependency info or jobs history' do
      before do
        allow(BuilddepInfo).to receive(:find)
        allow(Jobhistory).to receive(:find)
        get :rebuild_time, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
      end

      it { expect(flash[:error]).to start_with('Could not collect infos about repository') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'normal flow' do
      before do
        allow(BuilddepInfo).to receive(:find).and_return([])
        allow(Jobhistory).to receive(:find).and_return([])
      end

      context 'with diststats generated' do
        before do
          path = Xmlhash::XMLHash.new({'package' => 'package_name' })
          longestpaths_xml = Xmlhash::XMLHash.new({ 'longestpath' => Xmlhash::XMLHash.new({'path' => path }) })
          allow_any_instance_of(Webui::ProjectController).to receive(:call_diststats).and_return(longestpaths_xml)
          get :rebuild_time, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], [], ["package_name"]]) }
      end

      context 'with diststats not generated' do
        before do
          allow_any_instance_of(Webui::ProjectController).to receive(:call_diststats)
          get :rebuild_time, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], []]) }
      end
    end
  end

  describe 'GET #rebuild_time_png' do
    context 'with an invalid key' do
      before do
        get :rebuild_time_png, params: { project: user.home_project, key: 'invalid_key' }
      end

      it { expect(response.body).to be_empty }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end

    context 'with a valid key' do
      before do
        Rails.cache.write("rebuild-valid_key.png", "PNG Content")
        get :rebuild_time_png, params: { project: user.home_project, key: 'valid_key' }
      end

      it { expect(response.body).to eq("PNG Content") }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end
  end

  describe 'GET #requests' do
    before do
      get :requests, params: { project: apache_project, type: 'my_type', state: 'my_state' }
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

    shared_examples "a valid project saved" do
      it { expect(flash[:notice]).to start_with("Project '#{user.home_project_name}:my_project' was created successfully") }
      it { is_expected.to redirect_to(project_show_path("#{user.home_project_name}:my_project")) }
    end

    context "with a namespace called 'base'" do
      before do
        get :create, params: { project: { name: 'my_project' }, ns: user.home_project_name }
      end

      it { expect(assigns(:project).name).to eq("#{user.home_project_name}:my_project") }
      it_should_behave_like "a valid project saved"
    end

    context 'with a param called maintenance_project' do
      before do
        get :create, params: { project: { name: 'my_project' }, ns: user.home_project_name, maintenance_project: true }
      end

      it { expect(assigns(:project).kind).to eq('maintenance') }
      it_should_behave_like "a valid project saved"
    end

    context 'with a param that disables a flag' do
      shared_examples "a param that creates a disabled flag" do |param_name, flag_name|
        before do
          get :create, params: { :project => { name: 'my_project' }, :ns => user.home_project_name, param_name.to_sym => true }
        end

        it { expect(assigns(:project).flags.pluck(:flag)).to include(flag_name) }
        it { expect(assigns(:project).flags.find_by(flag: flag_name).status).to eq('disable') }
        it_should_behave_like "a valid project saved"
      end

      it_should_behave_like "a param that creates a disabled flag", :access_protection, 'access'
      it_should_behave_like "a param that creates a disabled flag", :source_protection, 'sourceaccess'
      it_should_behave_like "a param that creates a disabled flag", :disable_publishing, 'publish'
    end

    context 'with an invalid project data' do
      before do
        get :create, params: { project: { name: 'my invalid project' }, ns: user.home_project_name }
      end

      it { expect(flash[:error]).to start_with('Failed to save project') }
      it { is_expected.to redirect_to(root_url) }
    end
  end

  describe 'PATCH #update' do
    before do
      login user
    end

    context "with valid data" do
      before do
        patch :update, params: { id: user.home_project.id, project: { title: 'New Title' } }
      end

      it { expect(assigns(:project).title).to eq('New Title') }
      it { expect(flash[:notice]).to eq("Project was successfully updated.") }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context "with no valid data" do
      before do
        patch :update, params: { id: user.home_project.id, project: { name: 'non valid name' } }
      end

      it { expect(flash[:error]).to eq("Failed to update project") }
      it { is_expected.to render_template("webui/project/edit") }
      it { expect(response).to have_http_status(:success) }
    end
  end

  describe 'POST #remove_target_request' do
    before do
      login user
    end

    context "without target project" do
      before do
        expect(BsRequestActionDelete).to receive(:new).and_raise(BsRequestAction::UnknownTargetProject)
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it { expect(flash[:error]).to eq("BsRequestAction::UnknownTargetProject") }
      it { is_expected.to redirect_to(action: :index, controller: :repositories, project: apache_project) }
    end

    context "without target package" do
      before do
        expect(BsRequestActionDelete).to receive(:new).and_raise(BsRequestAction::UnknownTargetPackage)
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it { expect(flash[:error]).to eq("BsRequestAction::UnknownTargetPackage") }
      it { is_expected.to redirect_to(action: :index, project: apache_project, controller: :repositories) }
    end

    context "with proper params" do
      before do
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it do
        expect(flash[:success]).to eq("Created <a href='http://test.host/request/show/#{BsRequest.last.number}'>repository delete " +
                                      "request #{BsRequest.last.number}</a>")
      end
      it { is_expected.to redirect_to(controller: :request, action: :show, number: BsRequest.last.number) }
    end
  end

  describe 'POST #remove_path_from_target' do
    let(:path_element) { create(:path_element, repository: repo_for_user_home) }

    before do
      login user
    end

    it "without a repository param" do
      expect { post :remove_path_from_target, params: { project: user } }.to raise_error ActiveRecord::RecordNotFound
    end

    it "with a repository param but without a path param" do
      expect { post :remove_path_from_target, params: { repository: repo_for_user_home, project: user } }.to raise_error ActiveRecord::RecordNotFound
    end

    context "with a repository and path" do
      before do
        post :remove_path_from_target, params: { project: user.home_project, repository: repo_for_user_home, path: path_element }
      end

      it { expect(flash[:success]).to eq("Successfully removed path") }
      it { is_expected.to redirect_to(action: :index, project: user.home_project, controller: :repositories) }
      it { expect(repo_for_user_home.path_elements.count).to eq(0)}
    end

    context "with a target repository but letting the project invalid" do
      before do
        request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
        path_element # Needed before stubbing Project#valid? to false
        allow_any_instance_of(Project).to receive(:valid?).and_return(false)
        post :remove_path_from_target, params: { project: user.home_project, repository: repo_for_user_home, path: path_element }
      end

      it { expect(flash[:error]).to eq("Can not remove path: ") }
      it { is_expected.to redirect_to(root_url) }
      it { expect(assigns(:project).repositories.count).to eq(1)}
    end
  end

  describe 'GET #toggle_watch' do
    before do
      login user
    end

    it "with a project already whatched" do
      create(:watched_project, project: user.home_project, user: user)
      get :toggle_watch, params: { project: user.home_project }
      expect(user.watched_project_names).not_to include(user.home_project_name)
    end

    it "with a project not whatched" do
      get :toggle_watch, params: { project: user.home_project }
      expect(user.watched_project_names).to include(user.home_project_name)
    end

    it "redirects to back if a referer is there" do
      request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
      get :toggle_watch, params: { project: user.home_project }
      is_expected.to redirect_to(root_url)
    end

    it "redirects to project#show" do
      get :toggle_watch, params: { project: user.home_project }
      is_expected.to redirect_to(project_show_path(user.home_project))
    end
  end

  describe 'POST #unlock' do
    before do
      login user
    end

    context "with a project that is locked" do
      before do
        user.home_project.flags.create(flag: 'lock', status: 'enable')
      end

      context  'successfully unlocks the project' do
        before do
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }
        it { expect(flash[:notice]).to eq('Successfully unlocked project') }
      end

      context "with a project that has maintenance release requests" do
        let!(:bs_request) { create(:bs_request, type: 'maintenance_release', source_project: user.home_project.name) }

        before do
          user.home_project.update(kind: 'maintenance_incident')
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }
        it do
          expect(flash[:notice]).to eq("Project can't be unlocked: Unlock of maintenance incident #{user.home_project.name} is not possible," +
                                            " because there is a running release request: #{bs_request.id}")
        end
      end
    end

    context "with a project that isn't locked" do
      context  "project can't be unlocked" do
        before do
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }
        it { expect(flash[:notice]).to eq("Project can't be unlocked: is not locked") }
      end
    end
  end

  describe 'POST #remove_maintained_project' do
    before do
      login user
    end

    context "with maintained kind" do
      before do
        user.home_project.update(kind: 'maintenance')
      end

      context "maintained project successfully removed" do
        let(:maintained_project) { create(:maintained_project, project: user.home_project) }

        before do
          post :remove_maintained_project, params: { project: user.home_project, maintained_project: maintained_project.project.name }
        end

        it { expect(user.home_project.maintained_projects.where(project: user.home_project)).not_to exist }
        it { expect(flash[:notice]).to eq("Removed #{maintained_project.project.name} from maintenance") }
        it { is_expected.to redirect_to(action: 'maintained_projects', project: user.home_project) }
      end

      context "with an invalid maintained project" do
        before do
          request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
          post :remove_maintained_project, params: { project: user.home_project, maintained_project: user.home_project.name }
        end

        it { expect(flash[:error]).to eq("Failed to remove #{user.home_project.name} from maintenance") }
        it { is_expected.to redirect_to(root_url) }
      end

      # raise the exception in the before_action set_maintained_project
      it "#remove_maintained_project raise excepction with invalid maintained project" do
        expect {
          post :remove_maintained_project, params: { project: user.home_project, maintained_project: "invalid" }
        }.to raise_exception ActiveRecord::RecordNotFound
      end
    end

    context "#remove_maintained_project fails without maintenance kind for a valid maintained project" do
      let(:maintained_project) { create(:maintained_project, project: user.home_project) }

      before do
        post :remove_maintained_project, params: { project: user.home_project, maintained_project: maintained_project.project.name }
      end

      it { is_expected.to redirect_to(action: :show, project: user.home_project) }
    end
  end

  describe "POST #add_maintained_project" do
    before do
      login user
    end

    context "with a maintenance project (kind 'maintenance')" do
      before do
        user.home_project.update(kind: 'maintenance')
      end

      context "adding a valid maintained project" do
        before do
          post :add_maintained_project, params: { project: user.home_project, maintained_project: user.home_project.name }
        end

        it { expect(user.home_project.maintained_projects.where(project: user.home_project)).to exist }
        it { expect(flash[:notice]).to eq("Added #{user.home_project.name} to maintenance") }
        it { is_expected.to redirect_to(action: 'maintained_projects', project: user.home_project) }
      end

      context "adding an invalid project" do
        before do
          post :add_maintained_project, params: { project: user.home_project, maintained_project: "invalid project" }
        end

        it { expect(user.home_project.maintained_projects.where(project_id: user.home_project.id)).not_to exist }
        it { expect(flash[:error]).to eq("Failed to add invalid project to maintenance") }
        it { is_expected.to redirect_to(root_path) }
      end
    end

    context "without a maintenance project (kind 'maintenance')" do
      before do
        post :add_maintained_project, params: { project: user.home_project, maintained_project: user.home_project.name }
      end

      it { expect(user.home_project.maintained_projects.where(project: user.home_project)).not_to exist }
      it { is_expected.to redirect_to(action: :show, project: user.home_project) }
    end
  end

  describe 'POST #new_incident_request' do
    before do
      login user
      request.env["HTTP_REFERER"] = root_url # Needed for the redirect_to :back
    end

    it "without an existent project will raise an exception" do
      expect { post :new_incident_request, params: { project: 'non:existent:project' } }.to raise_error Project::UnknownObjectError
    end

    context "without a proper action for the maintenance project" do
      before do
        post :new_incident_request, params: { project: maintenance_project, description: "Fake description for a request" }
      end

      it { expect(flash[:error]).to eq("MaintenanceHelper::MissingAction") }
      it { is_expected.to redirect_to(root_url) }
    end

    context "with the proper params" do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_return(true)
        post :new_incident_request, params: { project: maintenance_project, description: "Fake description for a request" }
      end

      it { expect(flash[:success]).to eq("Created maintenance incident request") }
      it { is_expected.to redirect_to(project_show_path(maintenance_project)) }
    end
  end

  describe 'POST #edit_comment' do
    let(:package){ create(:package, name: 'home_package', project: user.home_project) }
    let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ProjectStatusPackageFailComment') }
    let(:text) { "The text to edit the comment" }

    before do
    end

    context 'with a user that can create attributes' do
      before do
        login user
        post :edit_comment, params: { project: user.home_project, package: package, text: text, format: 'js' }
      end

      it { expect(package.attribs.where(attrib_type: attribute_type).first.values.first.value).to eq(text) }
      it { expect(package.attribs.where(attrib_type: attribute_type).first.values.first.position).to eq(1) }
    end

    context "with a user that can't create attributes" do
      before do
        post :edit_comment, params: { project: user.home_project, package: package, text: text, last_comment: 'Last comment', format: 'js' }
      end

      it { expect(assigns(:comment)).to eq('Last comment') }
      it { expect(assigns(:error)).to eq("Can't create attributes in home_package") }
    end
  end

  describe 'GET #clear_failed_comment' do
    let(:package) { create(:package_with_failed_comment_attribute, name: 'my_package', project: user.home_project) }
    let(:attribute_type) { AttribType.find_by_name("OBS:ProjectStatusPackageFailComment") }

    before do
      login(user)
    end

    context 'with format html' do
      before do
        get :clear_failed_comment, params: { project: user.home_project, package: package }
      end

      it { expect(flash[:notice]).to eq("Cleared comments for packages.") }
      it { expect(response).to redirect_to(project_status_path(user.home_project)) }
      it { expect(package.attribs.where(attrib_type: attribute_type)).to be_empty }
    end

    context 'with format js' do
      before do
        get :clear_failed_comment, params: { project: user.home_project, package: package, format: 'js' }, xhr: true
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to eq("<em>Cleared comments for packages</em>") }
      it { expect(package.attribs.where(attrib_type: attribute_type)).to be_empty }
    end
  end

  describe 'POST #new_release_request' do
    before do
      login user
    end

    context 'with skiprequest param' do
      before do
        post :new_release_request, params: { project: apache_maintenance_incident_project, skiprequest: true }
      end

      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end

    context 'when raises an APIException' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_raise(APIException)
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:error]).to eq 'Internal problem while release request creation' }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end

    shared_examples 'a non APIException' do |exception_class|
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_raise(exception_class, "boom #{exception_class}")
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:error]).to eq "boom #{exception_class}" }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end

    context 'when raises a non APIException' do
      [Patchinfo::IncompletePatchinfo,
       BsRequestAction::UnknownProject,
       BsRequestAction::BuildNotFinished,
       BsRequestActionMaintenanceRelease::RepositoryWithoutReleaseTarget,
       BsRequestActionMaintenanceRelease::RepositoryWithoutArchitecture,
       BsRequestActionMaintenanceRelease::ArchitectureOrderMissmatch,
       BsRequestAction::VersionReleaseDiffers,
       BsRequestAction::UnknownTargetProject,
       BsRequestAction::UnknownTargetPackage].each do |exception_class|
        it_behaves_like 'a non APIException', exception_class
      end
    end

    context 'when is successful' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_return(true)
        allow_any_instance_of(BsRequest).to receive(:number).and_return(1)
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:success]).to eq "Created maintenance release request <a href='http://test.host/request/show/1'>1</a>" }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end
  end
end
