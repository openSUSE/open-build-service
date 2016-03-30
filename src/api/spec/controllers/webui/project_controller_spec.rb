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
        create(:confirmed_user, login: 'moi')
        create(:project)
        get :index, { show_all: true}
      end

      it { expect(assigns(:projects).length).to eq(2) }
      it { expect(Project.count).to eq(2) }
      it { is_expected.to render_template("webui/project/list") }
    end

    context 'showing not home projects' do
      before do
        create(:confirmed_user, login: 'moi')
        create(:project)
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

  describe 'GET #autocomplete_projectsindex' do
  end

  describe 'GET #autocomplete_incidents' do
  end

  describe 'GET #autocomplete_packages' do
  end

  describe 'GET #autocomplete_repositories' do
  end

  describe 'GET #users' do
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
