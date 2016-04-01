require 'rails_helper'

RSpec.describe Webui::ProjectController do
  describe 'CSRF protection' do
    before do
      # Needed because Rails disables it in test mode by default
      ActionController::Base.allow_forgery_protection = true

      login(create(:confirmed_user, login: 'tom'))
      create(:confirmed_user, login: 'moi')
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
        create(:project, name: 'home:moi')
        create(:project, name: 'AnotherProject')
        get :index, { show_all: true}
      end

      it { expect(assigns(:projects).length).to eq(2) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing not home projects' do
      before do
        create(:project, name: 'home:moi')
        create(:project, name: 'AnotherProject')
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

  describe 'GET #autocomplete_projects' do
    before do
      create(:project, name: 'Apache')
      create(:project, name: 'Apache2')
      create(:project, name: 'openSUSE')
      create(:maintenance_incident_project, name: 'ApacheMI')
    end

    context 'without search term' do
      before do
        get :autocomplete_projects
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache', 'Apache2', 'openSUSE') }
      it { expect(@json_response).not_to include('ApacheMI') }
    end

    context 'with search term' do
      before do
        get :autocomplete_projects, term: 'Apache'
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache', 'Apache2') }
      it { expect(@json_response).not_to include('ApacheMI') }
      it { expect(@json_response).not_to include('openSUSE') }
    end
  end

  describe 'GET #autocomplete_incidents' do
    before do
      create(:project, name: 'Apache')
      create(:maintenance_incident_project, name: 'ApacheMI')
      get :autocomplete_incidents, term: 'Apache'
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response).to contain_exactly('ApacheMI') }
    it { expect(@json_response).not_to include('Apache') }
  end

  describe 'GET #autocomplete_packages' do
    before do
      apache_project = create(:project, name: 'Apache')
      create(:package, name: 'Apache_Package', project: apache_project)
      create(:package, name: 'Apache2_Package', project: apache_project)
      another_project = create(:project, name: 'Another_Project')
      create(:package, name: 'Apache_Package_Another_Project', project: another_project)
    end

    context 'without search term' do
      before do
        get :autocomplete_packages, project: 'Apache'
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache_Package', 'Apache2_Package') }
      it { expect(@json_response).not_to include('Apache_Package_Another_Project') }
    end

    context 'with search term' do
      before do
        get :autocomplete_packages, { project: 'Apache', term: 'Apache2' }
        @json_response = JSON.parse(response.body)
      end

      it { expect(@json_response).to contain_exactly('Apache2_Package') }
      it { expect(@json_response).not_to include('Apache_Package') }
      it { expect(@json_response).not_to include('Apache_Package_Another_Project') }
    end
  end

  describe 'GET #autocomplete_repositories' do
    before do
      apache_project = create(:project, name: 'Apache')
      @repositories = create_list(:repository, 5, { project: apache_project })
      get :autocomplete_repositories, project: 'Apache'
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response).to match_array(@repositories.map {|r| r.name }) }
  end

  describe 'GET #users' do
    before do
      @project = create(:project)
      create(:relationship_project_user, project: @project, user: create(:confirmed_user))
      create(:relationship_project_user, project: @project, user: create(:confirmed_user))
      create(:relationship_project_group, project: @project, group: create(:group))

      another_project = create(:project)
      create(:relationship_project_user, project: another_project, user: create(:confirmed_user))
      create(:relationship_project_group, project: another_project, group: create(:group))
      get :users, project: @project
    end

    it { expect(assigns(:users)).to match_array(@project.users) }
    it { expect(assigns(:groups)).to match_array(@project.groups) }
    it { expect(assigns(:roles)).to match_array(Role.local_roles) }
  end

  describe 'GET #subprojects' do
  end

  describe 'GET #new' do
  end

  describe 'GET #new_incident' do
  end

  describe 'GET #new_package' do
  end

  describe 'GET #new_package_branch' do
  end

  describe 'GET #incident_request_dialog' do
  end

  describe 'GET #new_incident_request' do
  end

  describe 'GET #release_request_dialog' do
  end

  describe 'GET #new_release_request' do
  end

  describe 'GET #show' do
  end

  describe 'GET #linking_projects' do
  end

  describe 'GET #add_repository_from_default_list' do
  end

  describe 'GET #add_repository' do
  end

  describe 'GET #add_person' do
  end

  describe 'GET #add_group' do
  end

  describe 'GET #buildresult' do
  end

  describe 'GET #delete_dialog' do
  end

  describe 'GET #destroy' do
  end

  describe 'GET #update_target' do
  end

  describe 'GET #repositories' do
  end

  describe 'GET #repository_state' do
  end

  describe 'GET #rebuild_time' do
  end

  describe 'GET #rebuild_time_png' do
  end

  describe 'GET #requests' do
  end

  describe 'GET #create' do
  end

  describe 'GET #update' do
  end

  describe 'GET #save_repository' do
  end

  describe 'GET #save_distributions' do
  end

  describe 'GET #remove_target_request_dialog' do
  end

  describe 'GET #remove_target_request' do
  end

  describe 'GET #remove_target' do
  end

  describe 'GET #remove_path_from_target' do
  end

  describe 'GET #move_path' do
  end

  describe 'GET #monitor' do
  end

  describe 'GET #package_buildresult' do
  end

  describe 'GET #toggle_watch' do
  end

  describe 'GET #meta' do
  end

  describe 'GET #save_meta' do
  end

  describe 'GET #prjconf' do
  end

  describe 'GET #save_prjconf' do
  end

  describe 'GET #clear_failed_comment' do
  end

  describe 'GET #edit' do
  end

  describe 'GET #edit_comment_form' do
  end

  describe 'GET #edit_comment' do
  end

  describe 'GET #status' do
  end

  describe 'GET #maintained_projects' do
  end

  describe 'GET #add_maintained_project_dialog' do
  end

  describe 'GET #add_maintained_project' do
  end

  describe 'GET #remove_maintained_project' do
  end

  describe 'GET #maintenance_incidents' do
  end

  describe 'GET #unlock_dialog' do
  end

  describe 'GET #unlock' do
  end

  describe 'GET #main_object' do
  end

  describe 'GET #project_params' do
  end

  describe 'GET #set_maintained_project' do
  end

  describe 'GET #load_project_info' do
  end

  describe 'GET #load_releasetargets' do
  end

  describe 'GET #require_maintenance_project' do
  end

  describe 'GET #load_buildresult' do
  end

  describe 'GET #find_maintenance_infos' do
  end

  describe 'GET #convert_buildresult' do
  end

  describe 'GET #status_filter_packages' do
  end

  describe 'GET #status_gather_requests' do
  end

  describe 'GET #status_gather_attributes' do
  end

  describe 'GET #users_path' do
  end

  describe 'GET #set_project_by_name' do
  end
end
