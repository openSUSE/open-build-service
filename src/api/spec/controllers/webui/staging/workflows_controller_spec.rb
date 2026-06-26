RSpec.describe Webui::Staging::WorkflowsController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:managers_group) { create(:group) }
  let(:other_managers_group) { create(:group) }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow, project: project, managers_group: managers_group) }

  describe 'GET #new' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'non existent staging_workflow for project' do
      before do
        login(user)
        get :new, params: { project: project.name }
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(assigns[:staging_workflow].class).to be(Staging::Workflow) }
      it { expect(response).to render_template(:new) }
    end

    context 'with an existent staging_workflow for project' do
      before do
        login(user)
        staging_workflow
        get :new, params: { project: project.name }
      end

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(response).to redirect_to(staging_workflow_path(project)) }
    end
  end

  describe 'POST #create' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'a staging_workflow and staging_projects' do
      subject { project.staging }

      before do
        login(user)
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:A', 'home:tom:Staging:B') }
      it { expect(response).to redirect_to(staging_workflow_path(project)) }
      it { expect(subject.managers_group).to eq(managers_group) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with existent stagings projects' do
      subject { project.staging }

      let!(:staging_a) { create(:project, name: "#{project}:Staging:A") }
      let!(:staging_b) { create(:project, name: "#{project}:Staging:B") }

      before do
        login(user)
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      it { expect(Staging::Workflow.count).to eq(1) }
      it { expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:A', 'home:tom:Staging:B') }
      it { expect(response).to redirect_to(staging_workflow_path(project)) }
      it { expect(subject.managers_group).to eq(managers_group) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'when it cannot find the managers group' do
      let(:params) { { project_name: project.name, managers_title: 'ItDoesNotExist' } }

      before do
        login(user)
        post :create, params: params
      end

      it { expect(response).to redirect_to(new_staging_workflow_path(project_name: project))  }
      it { expect(flash[:error]).to eq("Managers Group #{params[:managers_title]} couldn't be found") }
    end

    context 'when it fails to save the staging workflow' do
      before do
        login(user)
        allow_any_instance_of(Staging::Workflow).to receive(:save).and_return(false)
        post :create, params: { project: project.name, managers_title: managers_group.title }
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(response).to redirect_to(new_staging_workflow_path(project_name: project)) }
      it { expect(flash[:error]).to eq("Staging for #{project} couldn't be created") }
    end
  end

  describe 'GET #show' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'with an existent staging_workflow for project' do
      before do
        staging_workflow
        get :show, params: { workflow_project: project }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:show) }
    end
  end

  describe 'GET #edit' do
    before { staging_workflow }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'with an existent staging_workflow for project' do
      before do
        login(user)
        get :edit, params: { workflow_project: project }
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(assigns[:project]).to eq(project) }
      it { expect(response).to render_template(:edit) }
    end
  end

  describe 'DELETE #destroy' do
    let!(:staging_workflow) { create(:staging_workflow, project: project) }

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'a staging workflow and staging projects' do
      subject { project.staging }

      before do
        login(user)
        params = { workflow_project: project, staging_workflow: { staging_project_ids: project.staging.staging_projects.ids }, format: :js }
        delete :destroy, params: params
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(subject.staging_projects.count).to eq(0) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{project_show_path(project)}'") }
      it { expect(project.subprojects.count).to eq(0) }
    end

    context 'a staging workflow and one staging project' do
      subject { project.staging }

      before do
        login(user)
        params = { workflow_project: project, staging_workflow: { staging_project_ids: project.staging.staging_projects.ids.first }, format: :js }
        delete :destroy, params: params
      end

      it { expect(Staging::Workflow.count).to eq(0) }
      it { expect(subject.staging_projects.count).to eq(0) }
      it { expect(project.subprojects.count).to eq(1) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{project_show_path(project)}'") }
    end

    context 'a staging workflow unsuccessful' do
      before do
        login(user)
        allow_any_instance_of(Staging::Workflow).to receive(:destroy).and_return(false)
        params = { workflow_project: project, staging_workflow: { staging_project_ids: project.staging.staging_projects.ids }, format: :js }
        delete :destroy, params: params
      end

      it { expect(flash[:error]).not_to be_nil }
      it { expect(response.body).to eq("window.location='#{staging_workflow_path(project)}'") }
    end
  end

  describe 'PUT #update' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'without any problem' do
      subject { staging_workflow.reload }

      before do
        login(user)
        put :update, params: { workflow_project: staging_workflow.project, managers_title: other_managers_group.title }
      end

      it { expect(subject.managers_group).to eq(other_managers_group) }

      it 'assigns the new group and unassigns the old one' do
        subject.staging_projects.each do |staging_project|
          expect(staging_project.groups).to contain_exactly(other_managers_group)
        end
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:success]).not_to be_nil }
    end

    context 'with a failing save for staging workflow' do
      subject { staging_workflow.reload }

      before do
        login(user)
        allow_any_instance_of(Staging::Workflow).to receive(:save).and_return(false)
        put :update, params: { workflow_project: staging_workflow.project, managers_title: other_managers_group.title }
      end

      it { expect(subject.managers_group).to eq(managers_group) }

      it 'don\'t assigns the new group and unassigns the old one' do
        subject.staging_projects.each do |staging_project|
          expect(staging_project.groups).to contain_exactly(managers_group)
        end
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:error]).not_to be_nil }
    end
  end
end
