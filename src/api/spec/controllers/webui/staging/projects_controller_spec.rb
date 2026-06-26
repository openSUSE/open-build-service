RSpec.describe Webui::Staging::ProjectsController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow, project: project) }

  describe 'POST #create' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    after do
      ActiveJob::Base.queue_adapter = :inline
    end

    it { is_expected.to use_after_action(:verify_authorized) }

    context 'a staging_project' do
      subject { staging_workflow }

      before do
        login(user)
        post :create, params: { workflow_project: staging_workflow.project, staging_project_name: 'home:tom:My:Projects' }
      end

      it { expect(Project.count).to eq(4) }

      it 'create a new staging project' do
        subject.reload
        expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:A', 'home:tom:Staging:B', 'home:tom:My:Projects')
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(CreateProjectLogEntryJob).to have_been_enqueued }

      it 'assigns the managers group' do
        expect(Project.find_by_name('home:tom:My:Projects').groups).to contain_exactly(subject.managers_group)
      end
    end

    context 'an existent non-staging project' do
      subject { staging_workflow }

      let!(:existent_project) { create(:project, name: "#{project}:new-staging", maintainer: user) }

      before do
        login(user)
        post :create, params: { workflow_project: staging_workflow.project, staging_project_name: existent_project.name }
      end

      it { expect(Project.count).to eq(4) }
      it { expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:A', 'home:tom:Staging:B', existent_project.name) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:success]).not_to be_nil }
      it { expect(CreateProjectLogEntryJob).to have_been_enqueued }

      it 'assigns the managers group' do
        expect(Project.find_by_name(existent_project.name).groups).to contain_exactly(subject.managers_group)
      end
    end

    context 'an existent staging project' do
      subject { staging_workflow }

      before do
        login(user)
        post :create, params: { workflow_project: staging_workflow.project, staging_project_name: 'home:tom:Staging:A' }
      end

      it { expect(Project.count).to eq(3) }
      it { expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:A', 'home:tom:Staging:B') }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:error]).not_to be_nil }
      it { expect(CreateProjectLogEntryJob).not_to have_been_enqueued }
    end

    context 'when the user does not have permissions to create that project' do
      before do
        login(user)
        post :create, params: { workflow_project: staging_workflow.project, staging_project_name: 'Apache' }
      end

      it { expect(Project.where(name: 'Apache')).not_to exist }
      it { expect(flash[:error]).to eq('Sorry, you are not authorized to create this project.') }
      it { expect(CreateProjectLogEntryJob).not_to have_been_enqueued }
    end

    context 'when it fails to save' do
      subject { staging_workflow }

      before do
        staging_workflow
        allow_any_instance_of(Project).to receive(:valid?).and_return(false)
        login(user)
        post :create, params: { workflow_project: staging_workflow.project, staging_project_name: 'home:tom:My:Projects' }
      end

      it { expect(Project.count).to eq(3) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:error]).not_to be_nil }
      it { expect(CreateProjectLogEntryJob).not_to have_been_enqueued }
    end
  end

  describe 'GET #show' do
    subject { staging_workflow }

    context 'a non-existent staging project' do
      before do
        staging_workflow
        get :show, params: { workflow_project: staging_workflow.project, project_name: 'non-existent' }
      end

      it { expect(response).to redirect_to(staging_workflow_path(subject)) }
      it { expect(flash[:error]).to have_text('Staging Project "non-existent" doesn\'t exist for this Staging.') }
    end

    context 'an existent staging project' do
      let(:staging_project) { staging_workflow.staging_projects.first }

      before do
        staging_workflow
        get :show, params: { workflow_project: staging_workflow.project, project_name: staging_project.name }
      end

      it 'assigns staging_project' do
        expect(assigns(:staging_project)).to eq(staging_project)
      end

      it 'assigns project' do
        expect(assigns(:project)).to eq(subject.project)
      end

      it 'assigns staging_project_log_entries' do
        expect(assigns(:staging_project_log_entries)).not_to be_nil
      end

      it 'assigns group_hash' do
        expect(assigns(:groups_hash)).not_to be_nil
      end

      it 'assigns user_hash' do
        expect(assigns(:users_hash)).not_to be_nil
      end
    end
  end

  describe 'DELETE #destroy' do
    it { is_expected.to use_after_action(:verify_authorized) }

    context 'non existent staging project' do
      subject { staging_workflow }

      before do
        login(user)
        delete :destroy, params: { workflow_project: staging_workflow.project, project_name: 'fake_name' }
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:error]).not_to be_nil }
    end

    context 'with an existent staging_workflow for project' do
      subject { staging_workflow }

      let(:staging_project) { staging_workflow.staging_projects.first }

      before do
        login(user)
        delete :destroy, params: { workflow_project: staging_workflow.project, project_name: staging_project.name }
      end

      it 'destroy a staging project' do
        subject.reload
        expect(subject.staging_projects.map(&:name)).to contain_exactly('home:tom:Staging:B')
      end

      it { expect(assigns[:staging_workflow]).to eq(project.staging) }
      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
    end

    context 'with a staged requests' do
      subject { staging_workflow }

      let(:staging_project) { staging_workflow.staging_projects.first }
      let(:group) { staging_workflow.managers_group }
      let(:source_project) { create(:project, name: 'source_project') }
      let(:target_package) { create(:package, name: 'target_package', project: project) }
      let(:source_package) { create(:package, name: 'source_package', project: source_project) }
      let(:other_user) { create(:confirmed_user, :with_home, login: 'Iggy') }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               state: :review,
               creator: other_user,
               target_package: target_package,
               source_package: source_package,
               description: 'BsRequest 1',
               review_by_group: group)
      end

      before do
        bs_request.staging_project = staging_project
        bs_request.save
        login(user)
        delete :destroy, params: { workflow_project: staging_workflow.project, project_name: staging_project.name }
      end

      it { expect(response).to redirect_to(edit_staging_workflow_path(subject.project)) }
      it { expect(flash[:error]).to include('could not be deleted because it has staged requests.') }
    end
  end

  describe 'GET #preview_copy' do
    it { is_expected.to use_after_action(:verify_authorized) }
  end

  describe 'POST #copy' do
    let(:original_staging_project_name) { staging_workflow.staging_projects.first.name }
    let(:staging_project_copy_name) { "#{original_staging_project_name}-copy" }
    let(:params) do
      {
        workflow_project: staging_workflow.project,
        project_name: original_staging_project_name,
        staging_project_copy_name: staging_project_copy_name
      }
    end

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    after do
      ActiveJob::Base.queue_adapter = :inline
    end

    it { is_expected.to use_after_action(:verify_authorized) }

    it 'queues a StagingProjectCopyJob job' do
      login(user)

      expect { post :copy, params: params }.to have_enqueued_job(StagingProjectCopyJob).with(staging_workflow.project.name,
                                                                                             original_staging_project_name,
                                                                                             staging_project_copy_name,
                                                                                             user.id)
    end
  end
end
