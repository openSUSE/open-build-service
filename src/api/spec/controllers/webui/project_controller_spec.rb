require 'webmock/rspec'

RSpec.describe Webui::ProjectController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }
  let(:apache2_project) { create(:project, name: 'Apache2') }
  let(:opensuse_project) { create(:project, name: 'openSUSE') }
  let(:apache_maintenance_incident_project) { create(:maintenance_incident_project, name: 'ApacheMI', maintenance_project: nil) }
  let(:home_moi_project) { create(:project, name: 'home:moi') }
  let(:maintenance_project) { create(:maintenance_project, name: 'maintenance_project') }
  let(:project_with_package) { create(:project_with_package, name: 'NewProject', package_name: 'PackageExample') }
  let(:repo_for_user_home) { create(:repository, project: user.home_project) }
  let(:json_response) { response.parsed_body }

  describe 'CSRF protection' do
    before do
      # Needed because Rails disables it in test mode by default
      ActionController::Base.allow_forgery_protection = true

      login user
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it 'protects forms without authenticity token' do
      expect { post :save_person, params: { project: user.home_project } }.to raise_error ActionController::InvalidAuthenticityToken
    end
  end

  describe 'PATCH #update' do
    let(:project) { user.home_project }

    context 'with valid parameters' do
      before do
        login user
        patch :update, params: { id: project.id, project: { description: 'My projects description', title: 'My projects title' }, format: :js }
        project.reload
      end

      it { expect(flash[:success]).to eq('Project was successfully updated.') }
      it { expect(project.title).to eq('My projects title') }
      it { expect(project.description).to eq('My projects description') }
    end

    context 'with invalid data' do
      before do
        login user
        patch :update, params: { id: project.id, project: { description: 'My projects description', title: 'My projects title' * 200 }, format: :js }
        project.reload
      end

      it { expect(flash[:error]).to eq('Failed to update the project.') }
      it { expect(project.title).to be_nil }
      it { expect(project.description).to be_nil }
    end
  end

  describe 'GET #autocomplete_projects' do
    before do
      apache_project
      apache2_project
      opensuse_project
      apache_maintenance_incident_project
    end

    context 'without search term' do
      before do
        get :autocomplete_projects
      end

      it { expect(json_response).to contain_exactly(apache_project.name, apache2_project.name, opensuse_project.name) }
      it { expect(json_response).not_to include(apache_maintenance_incident_project.name) }
    end

    context 'with search term' do
      before do
        get :autocomplete_projects, params: { term: 'Apache' }
      end

      it { expect(json_response).to contain_exactly(apache_project.name, apache2_project.name) }
      it { expect(json_response).not_to include(apache_maintenance_incident_project.name) }
      it { expect(json_response).not_to include(opensuse_project.name) }
    end

    context 'with a subprojects' do
      let!(:apache_subproject) { create(:project, name: 'Apache:subproject') }

      context 'and searching for parent project' do
        before do
          get :autocomplete_projects, params: { term: 'Apache' }
        end

        it { expect(json_response).to include(apache_subproject.name) }
      end
    end
  end

  describe 'GET #autocomplete_incidents' do
    before do
      apache_project
      apache_maintenance_incident_project
      get :autocomplete_incidents, params: { term: 'Apache' }
    end

    it { expect(json_response).to contain_exactly(apache_maintenance_incident_project.name) }
    it { expect(json_response).not_to include(apache_project.name) }
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
      end

      it { expect(json_response).to be_nil }
    end

    context 'without search term' do
      before do
        get :autocomplete_packages, params: { project: apache_project }
      end

      it { expect(json_response).to contain_exactly('Apache_Package', 'Apache2_Package') }
      it { expect(json_response).not_to include('Apache_Package_Another_Project') }
    end

    context 'with search term' do
      before do
        get :autocomplete_packages, params: { project: apache_project, term: 'Apache2' }
      end

      it { expect(json_response).to contain_exactly('Apache2_Package') }
      it { expect(json_response).not_to include('Apache_Package') }
      it { expect(json_response).not_to include('Apache_Package_Another_Project') }
    end
  end

  describe 'GET #autocomplete_repositories' do
    let!(:repositories) { create_list(:repository, 5, project: apache_project) }

    before do
      get :autocomplete_repositories, params: { project: apache_project }
    end

    it { expect(json_response).to match_array(repositories.map(&:name)) }
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
        expect(assigns(:show_restore_message)).to be(false)
      end
    end

    context 'for deleted projects' do
      before do
        allow(Project).to receive(:deleted?).and_return(true)
        get :new, params: { name: apache_project.name, restore_option: true }
      end

      it 'shows a hint for restoring the deleted project' do
        expect(assigns(:show_restore_message)).to be(true)
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

      expect(Project.find_by_name('not-allowed-to-create')).to be_nil
      expect(flash[:error]).to match(/not authorized to create/)
    end

    it 'restores a project' do
      allow(Project).to receive_messages(deleted?: true, restore: fake_project)

      post :restore, params: { project: 'project_name' }

      expect(flash[:success]).to match(/restored/)
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

    context 'with comments' do
      before do
        apache_project.comments << build(:comment_project, user: user)
        get :show, params: { project: apache_project }
      end

      it { expect(assigns(:comments)).to match_array(apache_project.comments) }
    end
  end

  describe 'GET #buildresult' do
    let(:summary) { Xmlhash::XMLHash.new('statuscount' => { 'code' => 'succeeded', 'count' => '1' }) }
    let(:build_result) do
      {
        'result' => Xmlhash::XMLHash.new(
          'repository' => 'openSUSE',
          'arch' => 'x86_64',
          'code' => 'published',
          'state' => 'published',
          'summary' => summary
        )
      }
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
    it { expect(status_count).to have_attributes(code: 'succeeded', count: '1') }
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
        it { expect(flash[:success]).to eq('Project was successfully removed.') }
      end

      context 'not having a parent project' do
        before do
          delete :destroy, params: { project: user.home_project }
        end

        it { expect(Project.count).to eq(0) }
        it { is_expected.to redirect_to(action: :index) }
        it { expect(flash[:success]).to eq('Project was successfully removed.') }
      end
    end

    context 'with check_weak_dependencies disabled' do
      before do
        allow_any_instance_of(Project).to receive(:check_weak_dependencies?).and_return(false)
        delete :destroy, params: { project: user.home_project }
      end

      it { expect(Project.count).to eq(1) }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
      it { expect(flash[:error]).to start_with("Project can't be removed:") }
    end
  end

  describe 'GET #requests' do
    before do
      get :requests, params: { project: apache_project, type: 'my_type', state: 'my_state' }
    end

    it { expect(assigns(:default_request_type)).to eq('my_type') }
    it { expect(assigns(:default_request_state)).to eq('my_state') }
  end

  describe 'GET #create' do
    before do
      login user
      request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
    end

    shared_examples 'a valid project saved' do
      it { expect(flash[:success]).to start_with("Project '#{user.home_project_name}:my_project' was created successfully") }
      it { is_expected.to redirect_to(project_show_path("#{user.home_project_name}:my_project")) }
    end

    context "with a namespace called 'base'" do
      before do
        post :create, params: { project: { name: 'my_project' }, namespace: user.home_project_name }
      end

      it { expect(assigns(:project).name).to eq("#{user.home_project_name}:my_project") }

      it_behaves_like 'a valid project saved'
    end

    context 'with a param called maintenance_project' do
      before do
        post :create, params: { project: { name: 'my_project' }, namespace: user.home_project_name, maintenance_project: true }
      end

      it { expect(assigns(:project).kind).to eq('maintenance') }

      it_behaves_like 'a valid project saved'
    end

    context 'with a param that disables a flag' do
      shared_examples 'a param that creates a disabled flag' do |param_name, flag_name|
        before do
          post :create, params: { project: { name: 'my_project' }, namespace: user.home_project_name, param_name.to_sym => true }
        end

        it { expect(assigns(:project).flags.first.flag).to eq(flag_name) }
        it { expect(assigns(:project).flags.find_by(flag: flag_name).status).to eq('disable') }

        it_behaves_like 'a valid project saved'
      end

      it_behaves_like 'a param that creates a disabled flag', :access_protection, 'access'
      it_behaves_like 'a param that creates a disabled flag', :source_protection, 'sourceaccess'
      it_behaves_like 'a param that creates a disabled flag', :disable_publishing, 'publish'
    end

    context 'with an invalid project data' do
      before do
        post :create, params: { project: { name: 'my invalid project' }, namespace: user.home_project_name }
      end

      it { expect(flash[:error]).to start_with('Failed to save project') }
      it { is_expected.to redirect_to(root_url) }
    end
  end

  describe 'POST #remove_target_request' do
    before do
      login user
    end

    context 'without target project' do
      before do
        allow(BsRequestActionDelete).to receive(:new).and_raise(BsRequestAction::Errors::UnknownTargetProject)
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it { expect(flash[:error]).to eq('BsRequestAction::Errors::UnknownTargetProject') }
      it { is_expected.to redirect_to(action: :index, controller: :repositories, project: apache_project) }
    end

    context 'without target package' do
      before do
        allow(BsRequestActionDelete).to receive(:new).and_raise(BsRequestAction::Errors::UnknownTargetPackage)
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it { expect(flash[:error]).to eq('BsRequestAction::Errors::UnknownTargetPackage') }
      it { is_expected.to redirect_to(action: :index, project: apache_project, controller: :repositories) }
    end

    context 'with proper params' do
      before do
        post :remove_target_request, params: { project: apache_project, description: 'Fake description' }
      end

      it do
        expect(flash[:success]).to eq("Created <a href='http://test.host/request/show/#{BsRequest.last.number}'>repository delete " \
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

    it 'without a repository param' do
      expect { post :remove_path_from_target, params: { project: user.home_project } }.to raise_error ActiveRecord::RecordNotFound
    end

    it 'with a repository param but without a path param' do
      expect { post :remove_path_from_target, params: { repository: repo_for_user_home.id, project: user.home_project } }.to raise_error ActiveRecord::RecordNotFound
    end

    context 'with a repository and path' do
      before do
        post :remove_path_from_target, params: { project: user.home_project, repository: repo_for_user_home.id, path: path_element }
      end

      it { expect(flash[:success]).to eq('Successfully removed path') }
      it { is_expected.to redirect_to(action: :index, project: user.home_project, controller: :repositories) }
      it { expect(repo_for_user_home.path_elements.count).to eq(0) }
    end

    context 'with a target repository but letting the project invalid' do
      before do
        request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
        path_element # Needed before stubbing Project#valid? to false
        allow_any_instance_of(Project).to receive(:valid?).and_return(false)
        post :remove_path_from_target, params: { project: user.home_project, repository: repo_for_user_home.id, path: path_element }
      end

      it { expect(flash[:error]).to eq('Can not remove path: ') }
      it { is_expected.to redirect_to(root_url) }
      it { expect(assigns(:project).repositories.count).to eq(1) }
    end
  end

  describe 'POST #unlock' do
    before do
      login user
    end

    context 'with a project that is locked' do
      before do
        user.home_project.flags.create(flag: 'lock', status: 'enable')
      end

      context  'successfully unlocks the project' do
        before do
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }
        it { expect(flash[:success]).to eq('Successfully unlocked project') }
      end

      context 'with a project that has maintenance release requests' do
        let!(:bs_request) { create(:bs_request, type: 'maintenance_release', source_project: user.home_project) }

        before do
          user.home_project.update(kind: 'maintenance_incident')
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }

        it do
          expect(flash[:error]).to eq("Project can't be unlocked: Unlock of maintenance incident #{user.home_project.name} is not possible, " \
                                      "because there is a running release request: #{bs_request.id}")
        end
      end
    end

    context "with a project that isn't locked" do
      context  "project can't be unlocked" do
        before do
          post :unlock, params: { project: user.home_project }
        end

        it { is_expected.to redirect_to(action: :show, project: user.home_project) }
        it { expect(flash[:error]).to eq("Project can't be unlocked: is not locked") }
      end
    end
  end

  describe 'POST #edit_comment' do
    let(:package) { create(:package, name: 'home_package', project: user.home_project) }
    let(:attribute_type) { AttribType.find_by_namespace_and_name!('OBS', 'ProjectStatusPackageFailComment') }
    let(:text) { 'The text to edit the comment' }

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
        post :edit_comment, params: { project: user.home_project, package: package, text: text, last_comment: 'Last comment' }
      end

      it { expect(response).to redirect_to(new_session_path) }
    end
  end

  describe 'GET #clear_failed_comment' do
    let(:package) { create(:package_with_failed_comment_attribute, name: 'my_package', project: user.home_project) }
    let(:attribute_type) { AttribType.find_by_name('OBS:ProjectStatusPackageFailComment') }

    before do
      login(user)
    end

    context 'with format html' do
      before do
        get :clear_failed_comment, params: { project: user.home_project, package: package }
      end

      it { expect(flash[:success]).to eq('Cleared comments for packages.') }
      it { expect(response).to redirect_to(project_status_path(user.home_project)) }
      it { expect(package.attribs.where(attrib_type: attribute_type)).to be_empty }
    end

    context 'with format js' do
      before do
        get :clear_failed_comment, params: { project: user.home_project, package: package, format: 'js' }, xhr: true
      end

      it { expect(response).to have_http_status(:success) }
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

    context 'when raises an APIError' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_raise(APIError)
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:error]).to eq('Internal problem while release request creation') }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end

    shared_examples 'a non APIError' do |error_class|
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_raise(error_class, "boom #{error_class}")
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:error]).to eq("boom #{error_class}") }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end

    context 'when raises a non APIError' do
      [Patchinfo::IncompletePatchinfo,
       BsRequestAction::UnknownProject,
       BsRequestAction::BuildNotFinished,
       BsRequestActionMaintenanceRelease::RepositoryWithoutReleaseTarget,
       BsRequestActionMaintenanceRelease::RepositoryWithoutArchitecture,
       ArchitectureOrderMissmatch,
       BsRequestAction::VersionReleaseDiffers,
       BsRequestAction::Errors::UnknownTargetProject,
       BsRequestAction::Errors::UnknownTargetPackage].each do |error_class|
        it_behaves_like 'a non APIError', error_class
      end
    end

    context 'when is successful' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_return(true)
        allow_any_instance_of(BsRequest).to receive(:number).and_return(1)
        post :new_release_request, params: { project: apache_maintenance_incident_project }
      end

      it { expect(flash[:success]).to eq("Created maintenance release request <a href='http://test.host/request/show/1'>1</a>") }
      it { expect(response).to redirect_to(project_show_path(apache_maintenance_incident_project)) }
    end
  end

  describe 'POST #move_path' do
    context 'valid project' do
      let(:repository) { create(:repository, project: apache_project) }
      let(:path_element) { create(:path_element, repository: repository) }

      before do
        login admin_user
      end

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
          it { expect(flash[:success]).to eq('Path moved up successfully') }
          it { expect(response).to redirect_to(action: :index, controller: :repositories, project: apache_project) }
        end

        context 'direction down' do
          before do
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'down', path: path_element }
          end

          it { expect(path_element.reload.position).to eq(position) }
          it { expect(flash[:success]).to eq('Path moved down successfully') }
          it { expect(response).to redirect_to(action: :index, controller: :repositories, project: apache_project) }
        end
      end

      context 'three path elements' do
        let(:path_element2) { create(:path_element, repository: repository) }
        let(:path_element3) { create(:path_element, repository: repository) }
        let(:path_elements) { [path_element, path_element2, path_element3] }

        context 'direction up' do
          let(:move) do
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'up', path: path_elements[1] }
          end

          context 'response' do
            before do
              move
            end

            it { expect(flash[:success]).to eq('Path moved up successfully') }
            it { expect(response).to redirect_to(action: :index, controller: :repositories, project: apache_project) }
          end

          context 'elements position' do
            it { expect { move }.to change { path_elements[0].reload.position }.by(1) }
            it { expect { move }.to change { path_elements[1].reload.position }.by(-1) }
            it { expect { move }.not_to(change { path_elements[2].reload.position }) }
          end
        end

        context 'direction down' do
          let(:move) do
            post :move_path, params: { project: apache_project, repository: repository.id, direction: 'down', path: path_elements[1] }
          end

          context 'response' do
            before do
              move
            end

            it { expect(flash[:success]).to eq('Path moved down successfully') }
            it { expect(response).to redirect_to(action: :index, controller: :repositories, project: apache_project) }
          end

          context 'elements position' do
            it { expect { move }.not_to(change { path_elements[0].reload.position }) }
            it { expect { move }.to change { path_elements[1].reload.position }.by(1) }
            it { expect { move }.to change { path_elements[2].reload.position }.by(-1) }
          end
        end
      end
    end
  end

  describe 'GET #monitor' do
    let(:repo_for_user) { create(:repository, name: 'openSUSE_Tumbleweed', project: user.home_project) }
    let(:arch_i586) { Architecture.where(name: 'i586').first }
    let(:arch_x86_64) { Architecture.where(name: 'x86_64').first } # rubocop:disable Naming/VariableNumber
    let!(:package) { create(:package, project: user.home_project) }

    context 'with a project' do
      context 'without buildresult' do
        before do
          allow(Buildresult).to receive(:find_hashed).and_return({})
          get :monitor, params: { project: user.home_project, defaults: '1' }
        end

        it { expect(flash[:warning]).not_to be_nil }
        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'without buildresult and with failed param set to an integer' do
        before do
          allow(Buildresult).to receive(:find_hashed).and_return({})
          get :monitor, params: { project: user.home_project, defaults: '1', failed: '2' }
        end

        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'without buildresult and with failed param set to a string' do
        before do
          allow(Buildresult).to receive(:find_hashed).and_return({})
          get :monitor, params: { project: user.home_project, defaults: '1', failed: 'abc' }
        end

        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end

      context 'with buildresult' do
        context 'with results' do
          let(:additional_repo) { create(:repository, name: 'openSUSE_42.2', project: user.home_project) }
          let(:arch_s390x) { Architecture.where(name: 's390x').first }
          let!(:repository_achitecture_i586) { create(:repository_architecture, repository: repo_for_user, architecture: arch_i586) }
          let!(:repository_achitecture_x86_64) { create(:repository_architecture, repository: repo_for_user, architecture: arch_x86_64) } # rubocop:disable Naming/VariableNumber
          let!(:repository_achitecture_s390x) { create(:repository_architecture, repository: additional_repo, architecture: arch_s390x) }
          let(:fake_buildresult) do
            <<-XML
              <resultlist state="073db4412ce71471edaacf7291404276">
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
              </resultlist>
            XML
          end
          let(:statushash) do
            { 'openSUSE_Tumbleweed' => {
                'i586' => {
                  'c++' => { 'package' => 'c++', 'code' => 'succeeded' },
                  'redis' => { 'package' => 'redis', 'code' => 'failed' }
                },
                'x86_64' => {
                  'c++' => { 'package' => 'c++', 'code' => 'unresolvable', 'details' => 'nothing provides foo' },
                  'redis' => { 'package' => 'redis', 'code' => 'building', 'details' => 'building on obs-node-3' }
                }
              },
              'openSUSE_42.2' => {
                's390x' => {
                  'c++' => { 'package' => 'c++', 'code' => 'succeeded' },
                  'redis' => { 'package' => 'redis', 'code' => 'succeeded' }
                }
              } }
          end

          before do
            allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_buildresult)
            post :monitor, params: { project: user.home_project }
          end

          it { expect(assigns(:buildresult_unavailable)).to be_nil }
          it { expect(assigns(:packagenames)).to eq(['c++', 'redis']) }
          it { expect(assigns(:statushash)).to eq(statushash) }
          it { expect(assigns(:repoarray)).to eq([['openSUSE_42.2', ['s390x']], ['openSUSE_Tumbleweed', %w[i586 x86_64]]]) }

          it {
            expect(assigns(:repostatushash)).to eq('openSUSE_Tumbleweed' => { 'i586' => 'published', 'x86_64' => 'building' },
                                                   'openSUSE_42.2' => { 's390x' => 'outdated_published' })
          }

          it {
            expect(assigns(:repostatusdetailshash)).to eq('openSUSE_Tumbleweed' => { 'x86_64' => 'This repo is broken' },
                                                          'openSUSE_42.2' => {})
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
          allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::NotFoundError)
          post :monitor, params: { project: user.home_project, defaults: 'abc' }
        end

        it { expect(flash[:warning]).not_to be_nil }
        it { expect(response).to redirect_to(project_show_path(user.home_project)) }
      end
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

  describe '#filter_matches?' do
    let(:input) { 'ThisIsAPackage' }

    context 'a filter_string that matches' do
      subject { Webui::ProjectController.new.send(:filter_matches?, input, filter_string) }

      let(:filter_string) { 'Package' }

      it { is_expected.to be_truthy }
    end

    context 'a filter_string does not match' do
      subject { Webui::ProjectController.new.send(:filter_matches?, input, filter_string) }

      let(:filter_string) { '!Package' }

      it { is_expected.to be_falsey }
    end
  end
end
