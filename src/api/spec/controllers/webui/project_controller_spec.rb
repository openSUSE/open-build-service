require 'rails_helper'

RSpec.describe Webui::ProjectController do
  let(:user_moi) { create(:confirmed_user, login: "moi") }
  let(:user_tom) { create(:confirmed_user, login: "tom") }

  describe 'CSRF protection' do
    before do
      # Needed because Rails disables it in test mode by default
      ActionController::Base.allow_forgery_protection = true

      login(user_tom)
      user_moi
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

  describe 'PATCH #update' do
    let(:project) { Project.find_by_name(user_tom.home_project_name) }

    context "with valid parameters" do
      before do
        login user_tom
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
        login user_tom
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
    before do
      create(:project, name: 'Apache')
      @project = create(:project, name: 'Apache:Apache2')
      create(:project, name: 'Apache:Apache2:TestSubproject')
      create(:project, name: 'Apache:Apache2:TestSubproject2')
      create(:project, name: 'Another_Project')
      get :subprojects, project: @project
    end

    it { expect(assigns(:subprojects)).to match_array(@project.subprojects) }
    it { expect(assigns(:parentprojects)).to match_array(@project.ancestors) }
  end

  describe 'GET #new' do
    before do
      login(user_moi)
      get :new, name: 'ProjectName'
    end

    it { expect(assigns(:project)).to be_a(Project) }
    it { expect(assigns(:project).name).to eq('ProjectName') }
  end
end
