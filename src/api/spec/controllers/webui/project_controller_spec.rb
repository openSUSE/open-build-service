require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

# rubocop:disable Metrics/BlockLength
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
        allow(::Configuration).to receive(:unlisted_projects_filter) { "^home:.*" }
        home_moi_project
        another_project
        get :index, params: { show_all: true }
      end

      it { expect(assigns(:projects).length).to eq(2) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing filtered projects' do
      before do
        allow(::Configuration).to receive(:unlisted_projects_filter) { "^home:.*" }
        home_moi_project
        another_project
        get :index, params: { show_all: false }
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
        patch :update, params: { id: project.id, project: { description: "My projects description", title: "My projects title" * 200 } }
        project.reload
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(flash[:error]).to eq "Failed to update project" }
      it { expect(project.title).to be nil }
      it { expect(project.description).to be nil }
    end
  end

  describe 'GET #remove_target_request_dialog' do
    before do
      get :remove_target_request_dialog, xhr: true
    end

    it { is_expected.to respond_with(:success) }
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

    context 'with a subprojects' do
      let!(:apache_subproject) { create(:project, name: "Apache:subproject") }

      context 'and searching for parent project' do
        before do
          get :autocomplete_projects, params: { term: 'Apache' }
          @json_response = JSON.parse(response.body)
        end

        it { expect(@json_response).not_to include(apache_subproject.name) }
      end

      context 'and searching for parent project' do
        before do
          get :autocomplete_projects, params: { term: 'Apache:' }
          @json_response = JSON.parse(response.body)
        end

        it { expect(@json_response).to include(apache_subproject.name) }
      end
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

    context 'with a nonexistent project' do
      before do
        get :autocomplete_packages, params: { project: 'non:existent:project' }
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to eq(nil) }
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
      @subproject1 = create(:project, name: 'Apache:Apache2:TestSubproject')
      @subproject2 = create(:project, name: 'Apache:Apache2:TestSubproject2')
    end

    context 'subprojects' do
      before do
        get :subprojects, params: { project: @project }
      end

      it "has subprojects" do
        expect(assigns(:subprojects)).to match_array([@subproject1, @subproject2])
        expect(assigns(:parentprojects)).to contain_exactly(apache_project)
        expect(assigns(:siblings)).to be_empty
      end
    end

    context 'siblingprojects' do
      before do
        get :subprojects, params: { project: @subproject1 }
      end

      it "has siblingprojects" do
        expect(assigns(:subprojects)).to be_empty
        expect(assigns(:parentprojects)).to match_array([apache_project, @project])
        expect(assigns(:siblings)).to contain_exactly(@subproject2)
      end
    end
  end

  describe 'GET #new' do
    before do
      login user
    end

    context 'with a project name' do
      before do
        get :new, params: { name: 'ProjectName' }
      end

      it { expect(assigns(:project)).to be_a(Project) }
      it { expect(assigns(:project).name).to eq('ProjectName') }
    end

    context 'for projects that never existed before' do
      before do
        get :new, params: { name: apache_project.name, restore_option: true }
      end

      it 'does not show a restoration hint' do
        expect(assigns(:show_restore_message)).to eq(false)
      end
    end

    context 'for deleted projects' do
      before do
        allow(Project).to receive(:deleted?).and_return(true)
        get :new, params: { name: apache_project.name, restore_option: true }
      end

      it 'shows a hint for restoring the deleted project' do
        expect(assigns(:show_restore_message)).to eq(true)
      end
    end
  end

  describe 'POST #restore' do
    let(:fake_project) { create(:project) }

    before do
      login admin_user
    end

    it 'forbids project creation on invalid permissions' do
      login user

      post :restore, params: { project: 'not-allowed-to-create' }

      expect(Project.find_by_name('not-allowed-to-create')).to eq(nil)
      expect(flash[:error]).to match(/not authorized to create/)
    end

    it 'restores a project' do
      allow(Project).to receive(:deleted?).and_return(true)
      allow(Project).to receive(:restore).and_return(fake_project)

      post :restore, params: { project: 'project_name' }

      expect(flash[:notice]).to match(/restored/)
      expect(response).to redirect_to(project_show_path(project: fake_project.name))
    end

    it 'shows an error if project was never deleted' do
      allow(Project).to receive(:deleted?).and_return(false)
      post :restore, params: { project: 'project_name' }

      expect(flash[:error]).to match(/never deleted/)
      expect(response).to redirect_to(root_path)
    end
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
        allow(Directory).to receive(:hashed).and_return(Xmlhash::XMLHash.new('entry' => { 'name' => '_patchinfo' }))
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
      expect(assigns(:remote_projects)).to match_array(@remote_projects_created.map { |r| [r.id, r.name, r.title] })
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
      expect(response).to render_template('webui/project/add_person')
    end
  end

  describe 'GET #add_group' do
    it 'assigns the local roles' do
      login user
      get :add_group, params: { project: user.home_project }
      expect(response).to render_template('webui/project/add_group')
    end
  end

  describe 'GET #buildresult' do
    let(:summary) { Xmlhash::XMLHash.new({ 'statuscount' => { 'code' => 'succeeded', 'count' => '1' } }) }
    let(:build_result) do
      { 'result' => Xmlhash::XMLHash.new({ 'repository' => 'openSUSE',
                                          'arch' => 'x86_64', 'code' => 'published', 'state' => 'published', 'summary' => summary }) }
    end

    let(:local_build_result) { assigns(:project).buildresults['openSUSE'].first }
    let(:result) { { architecture: 'x86_64', code: 'published', repository: 'openSUSE', state: 'published' } }
    let(:status_count) { local_build_result.summary.first }

    before do
      allow(Buildresult).to receive(:find_hashed).and_return(Xmlhash::XMLHash.new(build_result))
      get :buildresult, params: { project: project_with_package }, xhr: true
    end

    it { expect(assigns(:project).buildresults).to have_key('openSUSE') }
    it { expect(local_build_result).to have_attributes(result) }
    it { expect(status_count).to have_attributes({ code: 'succeeded', count: '1' }) }
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

    context 'with bdep and jobs' do
      let(:bdep_url) do
        # FIXME: Hardcoding urls in test doesn't sound like a good idea
        "http://backend:5352/build/#{user.home_project.name}/#{repo_for_user_home.name}/x86_64/_builddepinfo"
      end
      let(:bdep_xml) do
        <<-XML
          "<builddepinfo>" +
            "<package name=\"gcc6\">" +
              "<pkgdep>gcc</pkgdep>" +
            "</package>" +
          "</builddepinfo>"
        XML
      end

      let(:jobs_url) do
        # FIXME: Hardcoding urls in test doesn't sound like a good idea
        "http://backend:5352/build/#{user.home_project.name}/#{repo_for_user_home.name}/x86_64/_jobhistory?code=succeeded&code=unchanged&limit=0"
      end
      let(:jobs_xml) do
        <<-XML
          "<jobhistory>" +
            "<package name=\"gcc6\">" +
              "<pkgdep>gcc</pkgdep>" +
            "</package>" +
          "</jobhistory>"
        XML
      end

      before do
        stub_request(:get, bdep_url).to_return(status: 200, body: bdep_xml)
        stub_request(:get, jobs_url).to_return(status: 200, body: jobs_xml)

        get :rebuild_time, params: {
          project:    user.home_project.name,
          repository: repo_for_user_home.name,
          arch:       'x86_64'
        }
      end

      it { expect(response).to have_http_status(:success) }
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
          path = Xmlhash::XMLHash.new({ 'package' => 'package_name' })
          longestpaths_xml = Xmlhash::XMLHash.new({ 'longestpath' => Xmlhash::XMLHash.new({ 'path' => path }) })
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
        post :create, params: { project: { name: 'my_project' }, ns: user.home_project_name }
      end

      it { expect(assigns(:project).name).to eq("#{user.home_project_name}:my_project") }
      it_should_behave_like "a valid project saved"
    end

    context 'with a param called maintenance_project' do
      before do
        post :create, params: { project: { name: 'my_project' }, ns: user.home_project_name, maintenance_project: true }
      end

      it { expect(assigns(:project).kind).to eq('maintenance') }
      it_should_behave_like "a valid project saved"
    end

    context 'with a param that disables a flag' do
      shared_examples "a param that creates a disabled flag" do |param_name, flag_name|
        before do
          post :create, params: { :project => { name: 'my_project' }, :ns => user.home_project_name, param_name.to_sym => true }
        end

        it { expect(assigns(:project).flags.first.flag).to eq(flag_name) }
        it { expect(assigns(:project).flags.find_by(flag: flag_name).status).to eq('disable') }
        it_should_behave_like "a valid project saved"
      end

      it_should_behave_like "a param that creates a disabled flag", :access_protection, 'access'
      it_should_behave_like "a param that creates a disabled flag", :source_protection, 'sourceaccess'
      it_should_behave_like "a param that creates a disabled flag", :disable_publishing, 'publish'
    end

    context 'with an invalid project data' do
      before do
        post :create, params: { project: { name: 'my invalid project' }, ns: user.home_project_name }
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
      it { expect(repo_for_user_home.path_elements.count).to eq(0) }
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
      it { expect(assigns(:project).repositories.count).to eq(1) }
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

  describe 'POST #save_meta' do
    before do
      login user
    end

    context 'with an nonexistent project' do
      let(:post_save_meta) { post :save_meta, params: { project: 'nonexistent_project' }, xhr: true }

      it { expect { post_save_meta }.to raise_error(Pundit::NotDefinedError) }
    end

    context 'with a valid project' do
      context 'without a valid meta' do
        before do
          post :save_meta, params: { project: user.home_project, meta: '<project name="home:tom"><title/></project>' }, xhr: true
        end

        it { expect(flash.now[:error]).not_to be_nil }
        it { expect(response).to have_http_status(400) }
      end

      context 'with an invalid devel project' do
        before do
          post :save_meta, params: { project: user.home_project,
                                     meta:    '<project name="home:tom"><title/><description/><devel project="non-existant"/></project>' }, xhr: true
        end

        it { expect(flash.now[:error]).to eq("Project with name 'non-existant' not found") }
        it { expect(response).to have_http_status(400) }
      end

      context 'with a valid meta' do
        before do
          post :save_meta, params: { project: user.home_project, meta: '<project name="home:tom"><title/><description/></project>' }, xhr: true
        end

        it { expect(flash.now[:success]).not_to be_nil }
        it { expect(response).to have_http_status(200) }
      end

      context 'with a non existing repository path' do
        let(:meta) do
          <<-HEREDOC
          <project name="home:tom">
            <title/>
            <description/>
            <repository name="not-existent">
              <path project="not-existent" repository="standard" />
            </repository>
          </project>
          HEREDOC
        end

        before do
          post :save_meta, params: { project: user.home_project, meta: meta }, xhr: true
        end

        it { expect(flash.now[:error]).to eq("A project with the name not-existent does not exist. Please update the repository path elements.") }
        it { expect(response).to have_http_status(400) }
      end
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
    let(:package) { create(:package, name: 'home_package', project: user.home_project) }
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

  describe 'GET #prjconf' do
    before do
      login user
    end

    context 'Can load project config' do
      before do
        get :prjconf, params: { project: apache_project }
      end

      it { expect(flash[:error]).to eq(nil) }
      it { expect(response).not_to redirect_to(controller: :project, nextstatus: 404) }
    end

    context 'Can not load project config' do
      before do
        allow_any_instance_of(ProjectConfigFile).to receive(:to_s).and_return(nil)
        get :prjconf, params: { project: apache_project }
      end

      it { expect(flash[:error]).not_to eq(nil) }
      it { expect(response).to redirect_to(controller: 'project', nextstatus: 404) }
    end
  end

  describe 'POST #save_prjconf' do
    before do
      login user
    end

    context 'can save a project config' do
      before do
        post :save_prjconf, params: { project: user.home_project.name, config: 'save config' }
      end

      it { expect(flash[:success]).to eq('Config successfully saved!') }
      it { expect(response.status).to eq(200) }
    end

    context 'cannot save a project config' do
      before do
        allow_any_instance_of(ProjectConfigFile).to receive(:save).and_return(nil)
        post :save_prjconf, params: { project: user.home_project.name, config: '' }
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response.status).to eq(400) }
    end

    context 'cannot save with an unauthorized user' do
      before do
        post :save_prjconf, params: { project: another_project.name, config: 'save config' }
      end

      it { expect(flash[:error]).to eq('Sorry, you are not authorized to update this Project.') }
      it { expect(response.status).to eq(302) }
      it { expect(response).to redirect_to(root_path) }
    end

    context 'with a non existing project' do
      let(:post_save_prjconf) { post :save_prjconf, params: { project: 'non:existing:project', config: 'save config' } }

      it 'raise a RecordNotFound Exception' do
        expect { post_save_prjconf }.to raise_error ActiveRecord::RecordNotFound
      end
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

  describe 'POST #move_path' do
    context 'valid project' do
      let(:repository) { create(:repository, project: apache_project) }
      let(:path_element) { create(:path_element, repository: repository) }

      context 'without direction' do
        it { expect { post :move_path, params: { project: apache_project } }.to raise_error ActionController::ParameterMissing }
      end

      context 'only one path_element' do
        let(:position) { path_element.position }

        context 'direction up' do
          before do
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'up', path: path_element }
          end

          it { expect(path_element.reload.position).to eq(position) }
          it { expect(flash[:notice]).to eq("Path moved up successfully") }
          it { expect(response).to redirect_to({ action: :index, controller: :repositories, project: apache_project }) }
        end

        context 'direction down' do
          before do
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'down', path: path_element }
          end

          it { expect(path_element.reload.position).to eq(position) }
          it { expect(flash[:notice]).to eq("Path moved down successfully") }
          it { expect(response).to redirect_to({ action: :index, controller: :repositories, project: apache_project }) }
        end
      end

      context 'three path elements' do
        let(:path_element_2) { create(:path_element, repository: repository) }
        let(:path_element_3) { create(:path_element, repository: repository) }
        let(:path_elements) { [path_element, path_element_2, path_element_3] }

        context 'direction up' do
          let(:move) {
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'up', path: path_elements[1] }
          }

          context 'response' do
            before do
              move
            end

            it { expect(flash[:notice]).to eq("Path moved up successfully") }
            it { expect(response).to redirect_to({ action: :index, controller: :repositories, project: apache_project }) }
          end

          context 'elements position' do
            it { expect { move }.to change { path_elements[0].reload.position }.by(1) }
            it { expect { move }.to change { path_elements[1].reload.position }.by(-1) }
            it { expect { move }.not_to change { path_elements[2].reload.position } }
          end
        end

        context 'direction down' do
          let(:move) {
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'down', path: path_elements[1] }
          }

          context 'response' do
            before do
              move
            end

            it { expect(flash[:notice]).to eq("Path moved down successfully") }
            it { expect(response).to redirect_to({ action: :index, controller: :repositories, project: apache_project }) }
          end

          context 'elements position' do
            it { expect { move }.not_to change { path_elements[0].reload.position } }
            it { expect { move }.to change { path_elements[1].reload.position }.by(1) }
            it { expect { move }.to change { path_elements[2].reload.position }.by(-1) }
          end
        end
      end
    end

    context 'with non existing project' do
      it { expect { post :move_path, params: { project: 'non:existent:project' } }.to raise_error ActiveRecord::RecordNotFound }
    end
  end

  describe 'GET #monitor' do
    let(:repo_for_user) { create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project) }
    let(:arch_i586) { Architecture.where(name: 'i586').first }
    let(:arch_x86_64) { Architecture.where(name: 'x86_64').first }
    let!(:package) { create(:package, project: user.home_project) }

    context 'with a project' do
      context 'without buildresult' do
        before do
          allow(Buildresult).to receive(:find).and_return(nil)
          get :monitor, params: { project: user.home_project, defaults: '1' }
        end

        it { expect(flash[:warning]).not_to be_nil }
        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'without buildresult and with failed param set to an integer' do
        before do
          allow(Buildresult).to receive(:find).and_return(nil)
          get :monitor, params: { project: user.home_project, defaults: '1', failed: '2' }
        end

        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'without buildresult and with failed param set to a string' do
        before do
          allow(Buildresult).to receive(:find).and_return(nil)
          get :monitor, params: { project: user.home_project, defaults: '1', failed: 'abc' }
        end

        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'with buildresult' do
        context 'with results' do
          let(:additional_repo) { create(:repository, name: 'openSUSE_42.2', project: user.home_project) }
          let(:arch_s390x) { Architecture.where(name: 's390x').first }
          let!(:repository_achitecture_i586) { create(:repository_architecture, repository: repo_for_user, architecture: arch_i586) }
          let!(:repository_achitecture_x86_64) { create(:repository_architecture, repository: repo_for_user, architecture: arch_x86_64) }
          let!(:repository_achitecture_s390x) { create(:repository_architecture, repository: additional_repo, architecture: arch_s390x) }
          let(:fake_buildresult) do
            Buildresult.new(
              '<resultlist state="073db4412ce71471edaacf7291404276">
                <result project="home:tom" repository="openSUSE_Tumbleweed" arch="i586" code="published" state="published">
                  <status package="c++" code="succeeded" />
                  <status package="redis" code="failed" />
                </result>
                <result project="home:tom" repository="openSUSE_Tumbleweed" arch="x86_64" code="building" state="building"
                    details="This repo is broken" >
                  <status package="c++" code="unresolvable">
                    <details>nothing provides foo</details>
                  </status>
                  <status package="redis" code="building">
                    <details>building on obs-node-3</details>
                  </status>
                </result>
                <result project="home:tom" repository="openSUSE_42.2" arch="s390x" code="published" state="published" dirty="true">
                  <status package="c++" code="succeeded" />
                  <status package="redis" code="succeeded" />
                </result>
              </resultlist>')
          end
          let(:statushash) do
            { "openSUSE_Tumbleweed" => {
                "i586"   => {
                  "c++"   => { "package" => "c++",   "code" => "succeeded" },
                  "redis" => { "package" => "redis", "code" => "failed" }
                },
                "x86_64" => {
                  "c++"   => { "package" => "c++",   "code" => "unresolvable", "details" => "nothing provides foo" },
                  "redis" => { "package" => "redis", "code" => "building", "details" => "building on obs-node-3" }
                }
            },
              "openSUSE_42.2"       => {
                "s390x" => {
                  "c++"   => { "package" => "c++",   "code" => "succeeded" },
                  "redis" => { "package" => "redis", "code" => "succeeded" }
                }
            } }
          end

          before do
            allow(Buildresult).to receive(:find).and_return(fake_buildresult)
            post :monitor, params: { project: user.home_project }
          end

          it { expect(assigns(:buildresult_unavailable)).to be_nil }
          it { expect(assigns(:packagenames)).to eq(['c++', 'redis']) }
          it { expect(assigns(:statushash)).to eq(statushash) }
          it { expect(assigns(:repohash)).to eq({ "openSUSE_Tumbleweed" => ["i586", "x86_64"], "openSUSE_42.2" => ["s390x"] }) }
          it {
            expect(assigns(:repostatushash)).to eq({ "openSUSE_Tumbleweed" => { "i586" => "published", "x86_64" => "building" },
                                                     "openSUSE_42.2"       => { "s390x" => "outdated_published" } })
          }
          it {
            expect(assigns(:repostatusdetailshash)).to eq({ "openSUSE_Tumbleweed" => { "x86_64" => "This repo is broken" },
                                                            "openSUSE_42.2"       => {} })
          }
          it { expect(response).to have_http_status(:ok) }
        end

        context 'without results' do
          before do
            post :monitor, params: { project: user.home_project }
          end

          it { expect(response).to have_http_status(:ok) }
        end
      end

      context 'without buildresult and defaults set to a non-integer' do
        before do
          allow(Buildresult).to receive(:find).and_return(nil)
          post :monitor, params: { project: user.home_project, defaults: 'abc' }
        end

        it { expect(flash[:warning]).not_to be_nil }
        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end
    end
  end

  describe 'GET #maintenance_incidents' do
    let(:maintenance) { create(:maintenance_project, name: 'suse:maintenance') }

    context 'with maintenance incident' do
      let(:maintenance_incident) { create(:maintenance_incident_project, name: 'suse:maintenance:incident', maintenance_project: maintenance) }
      let(:maintenance_incident_repo) { create(:repository, project: maintenance_incident) }
      let(:release_target) { create(:release_target, repository: maintenance_incident_repo, trigger: 'maintenance') }

      before do
        release_target
        login user
        get :maintenance_incidents, params: { project: maintenance }
      end

      it { expect(assigns(:incidents)).to eq([maintenance_incident]) }
      it { expect(response).to have_http_status(:ok) }
    end

    context 'without maintenance incident' do
      before do
        login user
        get :maintenance_incidents, params: { project: maintenance }
      end

      it { expect(assigns(:incidents)).to be_empty }
      it { expect(response).to have_http_status(:ok) }
    end
  end

  describe 'GET #edit_comment_form' do
    context 'edit a comment via AJAX' do
      before do
        get :edit_comment_form, params: { project: user.home_project }, xhr: true
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response).to render_template(:edit_comment_form) }
    end

    context 'edit a comment without xhr' do
      let(:call_edit_comment_form) { get :edit_comment_form, params: { project: user.home_project } }

      it { expect { call_edit_comment_form }.to raise_error(ActionController::RoutingError, 'Expected AJAX call') }
    end
  end

  describe 'GET #package_buildresult' do
    context 'with xhr request' do
      context 'with project' do
        let(:fake_buildresult) do
          Xmlhash::XMLHash.new(
            "state" => "c0a974eb305112d2fdf45f9ecc54a86b", "result" => [
              Xmlhash::XMLHash.new("project" => "home:tom", "repository" => "home_coolo_standard", "arch" => "i586", "code" => "published",
                                   "state" => "published", "status" => [
                                     Xmlhash::XMLHash.new("package" => "apache", "code" => "succeeded"),
                                     Xmlhash::XMLHash.new("package" => "obs-server", "code" => "succeeded")
                                   ]),
              Xmlhash::XMLHash.new("project" => "home:tom", "repository" => "home_coolo_standard", "arch" => "x86_64", "code" => "published",
                                   "state" => "published", "status" => [
                                     Xmlhash::XMLHash.new("package" => "apache", "code" => "succeeded"),
                                     Xmlhash::XMLHash.new("package" => "obs-server", "code" => "succeeded")
                                   ])
            ]
          )
        end
        let(:repohash) do
          { "home_coolo_standard" => ["i586", "x86_64"] }
        end

        let(:statushash) do
          { "home_coolo_standard" => {
            "i586"   => {
              "apache"     => { "package" => "apache", "code" => "succeeded" },
              "obs-server" => { "package" => "obs-server", "code" => "succeeded" }
            },
            "x86_64" => {
              "apache"     => { "package" => "apache", "code" => "succeeded" },
              "obs-server" => { "package" => "obs-server", "code" => "succeeded" }
            }
          } }
        end
        before do
          allow(Buildresult).to receive(:find_hashed).and_return(fake_buildresult)
          get :package_buildresult, params: { project: user.home_project }, xhr: true
        end

        it { expect(assigns(:repohash)).to eq(repohash) }
        it { expect(assigns(:statushash)).to eq(statushash) }
        it { expect(response).to have_http_status(:ok) }
      end

      context 'with project and package' do
        let(:fake_buildresult) do
          Xmlhash::XMLHash.new(
            "state" => "c0a974eb305112d2fdf45f9ecc54a86b", "result" => [
              Xmlhash::XMLHash.new("project" => "home:tom", "repository" => "home_coolo_standard", "arch" => "i586", "code" => "published",
                                   "state" => "published", "status" => [
                                     Xmlhash::XMLHash.new("package" => "obs-server", "code" => "succeeded")
                                   ]),
              Xmlhash::XMLHash.new("project" => "home:tom", "repository" => "home_coolo_standard", "arch" => "x86_64", "code" => "published",
                                   "state" => "published", "status" => [
                                     Xmlhash::XMLHash.new("package" => "obs-server", "code" => "succeeded")
                                   ])
            ]
          )
        end
        let(:repohash) do
          { "home_coolo_standard" => ["i586", "x86_64"] }
        end

        let(:statushash) do
          { "home_coolo_standard" => {
            "i586"   => {
              "obs-server" => { "package" => "obs-server", "code" => "succeeded" }
            },
            "x86_64" => {
              "obs-server" => { "package" => "obs-server", "code" => "succeeded" }
            }
          } }
        end
        let(:package) { create(:package, name: 'obs-server', project: user.home_project ) }

        before do
          allow(Buildresult).to receive(:find_hashed).and_return(fake_buildresult)
          get :package_buildresult, params: { project: user.home_project, package: package }, xhr: true
        end

        it { expect(assigns(:repohash)).to eq(repohash) }
        it { expect(assigns(:statushash)).to eq(statushash) }
        it { expect(response).to have_http_status(:ok) }
      end
    end
    context 'without xhr request' do
      let(:call_package_buildresult) { get :package_buildresult, params: { project: user.home_project } }

      it { expect { call_package_buildresult }.to raise_error(ActionController::RoutingError, 'Expected AJAX call') }
    end
  end

  describe 'GET #incident_request_dialog' do
    let!(:repo) { create(:repository, project: user.home_project) }
    let!(:release_target) { create(:release_target, repository: repo) }

    before do
      get :incident_request_dialog, params: { project: user.home_project }, xhr: true
    end

    it { expect(assigns[:releasetargets].count).to eq(1) }
    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #release_request_dialog' do
    before do
      get :release_request_dialog, params: { project: user.home_project }, xhr: true
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #add_maintained_project_dialog' do
    let(:maintenance_project) { create(:maintenance_project, name: 'MyProject') }

    before do
      get :add_maintained_project_dialog, params: { project: maintenance_project.name }, xhr: true
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #unlock_dialog' do
    before do
      get :unlock_dialog, params: { project: user.home_project }, xhr: true
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #meta' do
    before do
      login user
      get :meta, params: { project: user.home_project }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'GET #edit' do
    context 'when the user has access to the project' do
      before do
        login user
        get :edit, params: { project: user.home_project }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when the user does not have access to the project' do
      let!(:project_locked_flag) { create(:lock_flag, project: user.home_project) }

      before do
        login user
        get :edit, params: { project: user.home_project }
      end

      it { expect(response).to have_http_status(302) }
    end
  end

  describe 'GET #maintained_projects' do
    let!(:maintenance_project) { create(:maintenance_project, name: 'Project1') }
    let!(:maintained_project) { create(:maintained_project, maintenance_project: maintenance_project) }

    before do
      login user
      get :maintained_projects, params: { project: maintenance_project }
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(assigns[:maintained_projects]).to eq([maintained_project.project.name]) }
  end

  describe 'GET #save_person' do
    let(:new_user) { create(:user) }

    before do
      login user
      post :save_person, params: { project: user.home_project, role: 'maintainer', userid: new_user.login }
    end

    it { expect(response).to redirect_to(users_path) }
  end

  describe '#filter_matches?' do
    let(:input) { 'ThisIsAPackage' }

    context 'a filter_string that matches' do
      let(:filter_string) { 'Package' }

      subject { Webui::ProjectController.new.send(:filter_matches?, input, filter_string) }

      it { is_expected.to be_truthy }
    end

    context 'a filter_string does not match' do
      let(:filter_string) { '!Package' }

      subject { Webui::ProjectController.new.send(:filter_matches?, input, filter_string) }

      it { is_expected.to be_falsey }
    end
  end

  describe 'GET #status' do
    let(:params) { { project: project.name } }

    before do
      get :status, params: params
    end

    context 'no params set' do
      # NOTE: These project names need to be different for each context because otherwise the
      # test backend will fail to cleanup the backend packages which causes failures in this spec
      let!(:project) do
        create(:project, name: 'Apache22', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite3', title: 'mod_rewrite', description: 'url rewrite module')
      end

      it_behaves_like 'a project status controller'
    end

    context 'param format=json set' do
      let!(:project) do
        create(:project, name: 'Apache3', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite3', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, format: 'json' } }

      it_behaves_like 'a project status controller'
    end

    context 'param filter_devel is set' do
      let!(:project) do
        create(:project, name: 'Apache4', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite4', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, filter_devel: 'No Project' } }

      it { expect(assigns[:filter]).to eq('_none_') }
    end

    context 'param ignore_pending is set' do
      let!(:project) do
        create(:project, name: 'Apache5', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite5', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, ignore_pending: true } }

      it { expect(assigns[:ignore_pending]).to be_truthy }
    end

    context 'param limit_to_fails is set' do
      let!(:project) do
        create(:project, name: 'Apache6', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite6', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, limit_to_fails: 'false' } }

      it { expect(assigns[:limit_to_fails]).to be_falsey }
    end

    context 'param limit_to_old is set' do
      let!(:project) do
        create(:project, name: 'Apache7', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite7', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, limit_to_old: 'true' } }

      it { expect(assigns[:limit_to_old]).to be_truthy }
    end

    context 'param include_versions is set' do
      let!(:project) do
        create(:project, name: 'Apache8', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite8', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, include_versions: 'true' } }

      it { expect(assigns[:include_versions]).to be_truthy }
    end

    context 'param filter_for_user is set' do
      let!(:project) do
        create(:project, name: 'Apache9', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite9', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project: project.name, filter_for_user: admin_user.login } }

      it { expect(assigns[:filter_for_user]).to eq(admin_user.login) }
    end
  end
end
# rubocop:enable Metrics/BlockLength
