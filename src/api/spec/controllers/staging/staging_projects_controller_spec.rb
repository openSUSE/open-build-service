RSpec.describe Staging::StagingProjectsController do
  render_views

  let(:user) { create(:confirmed_user, :with_home, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:project_without_staging) { create(:project, name: 'foo_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }

  before do
    login user
  end

  describe 'GET #index', :vcr do
    context 'existing staging_workflow' do
      before do
        get :index, params: { staging_workflow_project: staging_workflow.project.name, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'not existing staging_workflow' do
      before do
        get :index, params: { staging_workflow_project: project_without_staging.name, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'GET #show' do
    context 'not existing staging workflow' do
      before do
        get :show, params: { staging_workflow_project: project_without_staging.name, staging_project_name: staging_project.name, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(response.body).to include("Staging Workflow for project \"#{project_without_staging.name}\" does not exist.") }
    end

    context 'not existing staging project' do
      let(:staging_project_name) { 'non-existent' }

      before do
        get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project_name, format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
      it { expect(response.body).to include("Staging Project \"#{staging_project_name}\" does not exist.") }
    end

    context 'valid project' do
      let(:broken_packages_backend) do
        <<~XML
          <resultlist state="e9e2a9641ea83ac9c8786c24ca57dc6f">
            <result project="home:foo:Staging:A" repository="openSUSE_Tumbleweed" arch="i586" code="published" state="published">
              <status package="barbar" code="failed" />
            </result>
            <result project="home:foo:Staging:A" repository="openSUSE_Tumbleweed" arch="x86_64" code="published" state="published">
              <status package="barbar" code="failed" />
            </result>
          </resultlist>
        XML
      end
      let(:broken_packages_path) { "#{CONFIG['source_url']}/build/#{staging_project.name}/_result?code=failed&code=broken&code=unresolvable" }

      let(:request_attributes) do
        {
          target_package: target_package,
          source_package: source_package
        }
      end

      let(:bs_request) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, staging_project: staging_project))
      end

      let(:untracked_request) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_project: staging_project))
      end

      let(:bs_request_to_review) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_project: staging_project, staging_project: staging_project))
      end

      let(:bs_request_missing_review) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_user: user, staging_project: staging_project))
      end

      before do
        stub_request(:get, broken_packages_path).and_return(body: broken_packages_backend)
        # staging select
        bs_request_to_review.change_review_state(:accepted, by_group: staging_workflow.managers_group.title)
        bs_request_missing_review.change_review_state(:accepted, by_group: staging_workflow.managers_group.title)
        untracked_request.change_review_state(:accepted, by_group: staging_workflow.managers_group.title)
        bs_request.change_review_state(:accepted, by_group: staging_workflow.managers_group.title)
      end

      context 'without requesting extra information' do
        before do
          get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml }
        end

        it { expect(response).to have_http_status(:success) }

        it { expect(response.body).not_to include("<staging_project name=\"#{staging_project.name}\" state=") }

        it 'returns the staging_project default xml' do
          expect(response.body).to have_css('staging_project > staged_requests', count: 0)
          expect(response.body).to have_css('staging_project > untracked_requests', count: 0)
          expect(response.body).to have_css('staging_project > obsolete_requests', count: 0)
          expect(response.body).to have_css('staging_project > missing_reviews', count: 0)
          expect(response.body).to have_css('staging_project > broken_packages', count: 0)
          expect(response.body).to have_css('staging_project > checks', count: 0)
          expect(response.body).to have_css('staging_project > history', count: 0)
        end
      end

      context 'with requests' do
        before do
          get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name,
                               requests: 1, format: :xml }
        end

        it { expect(response).to have_http_status(:success) }

        it { expect(response.body).not_to include("<staging_project name=\"#{staging_project.name}\" state=") }

        it 'returns the staging_project with requests xml' do
          expect(response.body).to have_css('staging_project > staged_requests', count: 1)
          expect(response.body).to have_css('staging_project > staged_requests > request', count: 3)
          expect(response.body).to have_css('staging_project > untracked_requests', count: 1)
          expect(response.body).to have_css('staging_project > untracked_requests > request', count: 1)
          expect(response.body).to have_css('staging_project > obsolete_requests', count: 1)
          expect(response.body).to have_css('staging_project > missing_reviews', count: 1)
          expect(response.body).to have_css('staging_project > missing_reviews > review', count: 1)
          expect(response.body).to have_css('staging_project > broken_packages', count: 0)
          expect(response.body).to have_css('staging_project > checks', count: 0)
          expect(response.body).to have_css('staging_project > history', count: 0)
        end
      end

      context 'with status info' do
        before do
          get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name,
                               status: 1, format: :xml }
        end

        it { expect(response).to have_http_status(:success) }

        it { expect(response.body).to include("<staging_project name=\"#{staging_project.name}\" state=") }

        it 'returns the staging_project with status xml' do
          expect(response.body).to have_css('staging_project > staged_requests', count: 0)
          expect(response.body).to have_css('staging_project > untracked_requests', count: 0)
          expect(response.body).to have_css('staging_project > obsolete_requests', count: 0)
          expect(response.body).to have_css('staging_project > missing_reviews', count: 0)
          expect(response.body).to have_css('staging_project > broken_packages', count: 1)
          expect(response.body).to have_css('staging_project > broken_packages > package', count: 2)
          expect(response.body).to have_css('staging_project > checks', count: 1)
          expect(response.body).to have_css('staging_project > history', count: 0)
        end
      end

      context 'with history' do
        before do
          get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name,
                               history: 1, format: :xml }
        end

        it { expect(response).to have_http_status(:success) }

        it { expect(response.body).not_to include("<staging_project name=\"#{staging_project.name}\" state=") }

        it 'returns the staging_project with history xml' do
          expect(response.body).to have_css('staging_project > staged_requests', count: 0)
          expect(response.body).to have_css('staging_project > untracked_requests', count: 0)
          expect(response.body).to have_css('staging_project > obsolete_requests', count: 0)
          expect(response.body).to have_css('staging_project > missing_reviews', count: 0)
          expect(response.body).to have_css('staging_project > broken_packages', count: 0)
          expect(response.body).to have_css('staging_project > history', count: 1)
        end
      end

      context 'with requests, status, history' do
        before do
          get :show, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name,
                               requests: 1, status: 1, history: 1, format: :xml }
        end

        it { expect(response).to have_http_status(:success) }

        it { expect(response.body).to include("<staging_project name=\"#{staging_project.name}\" state=") }

        it 'returns the staging_project with requests, status and history xml' do
          expect(response.body).to have_css('staging_project > staged_requests', count: 1)
          expect(response.body).to have_css('staging_project > staged_requests > request', count: 3)
          expect(response.body).to have_css('staging_project > untracked_requests', count: 1)
          expect(response.body).to have_css('staging_project > untracked_requests > request', count: 1)
          expect(response.body).to have_css('staging_project > obsolete_requests', count: 1)
          expect(response.body).to have_css('staging_project > missing_reviews', count: 1)
          expect(response.body).to have_css('staging_project > missing_reviews > review', count: 1)
          expect(response.body).to have_css('staging_project > broken_packages', count: 1)
          expect(response.body).to have_css('staging_project > broken_packages > package', count: 2)
          expect(response.body).to have_css('staging_project > history', count: 1)
        end
      end
    end
  end

  describe 'POST #copy' do
    let(:staging_workflow_project) { staging_workflow.project.name }
    let(:original_staging_project_name) { staging_workflow.staging_projects.first.name }
    let(:staging_project_copy_name) { "#{original_staging_project_name}-copy" }
    let(:params) do
      {
        staging_workflow_project: staging_workflow_project,
        staging_project_name: original_staging_project_name,
        staging_project_copy_name: staging_project_copy_name
      }
    end

    before do
      ActiveJob::Base.queue_adapter = :test
    end

    after do
      ActiveJob::Base.queue_adapter = :inline
    end

    it 'queues a StagingProjectCopyJob job' do
      expect { post :copy, format: :xml, params: params }.to have_enqueued_job(StagingProjectCopyJob).with(staging_workflow_project,
                                                                                                           original_staging_project_name,
                                                                                                           staging_project_copy_name,
                                                                                                           user.id)
    end
  end

  describe 'POST #accept' do
    render_views

    let(:params) { { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project_name } }

    before do
      staging_workflow
    end

    context 'when staging project does not exist' do
      subject! do
        post :accept, params: params, format: :xml
      end

      let(:staging_project_name) { 'non-existent' }

      it { is_expected.to have_http_status(:not_found) }
      it { expect(response.body).to match('Staging Project "non-existent" does not exist.') }
    end

    context 'when staging project is empty' do
      subject! do
        post :accept, params: params, format: :xml
      end

      let(:staging_project_name) { staging_project.name }

      it { is_expected.to have_http_status(:bad_request) }
      it { expect(response.body).to match('Staging Project is not acceptable: empty is not an acceptable state') }

      context 'with force parameter' do
        subject! do
          post :accept, params: params.merge(force: true), format: :xml
        end

        it 'still fails' do
          expect(subject).to have_http_status(:bad_request)
          expect(response.body).to match('Staging Project is not acceptable: is not in state')
        end
      end
    end

    context 'when project has a request', :vcr do
      subject do
        post :accept, params: params, format: :xml
      end

      let(:staging_owner) { create(:confirmed_user, login: 'staging-hero') }
      let(:staging_project_name) { staging_project.name }
      let(:requester) { create(:confirmed_user, login: 'requester') }
      let(:target_project) { create(:project, name: 'target_project') }
      let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
      let(:target_package) { create(:package, name: 'target_package', project: target_project) }
      let(:source_package) { create(:package, name: 'source_package', project: source_project) }
      let(:build_flag_disabled) { staging_project.disabled_for?('build', nil, nil) }
      let!(:target_relationship) { create(:relationship, project: target_project, user: user) }
      let!(:staging_relationship) { create(:relationship, project: staging_project, user: staging_owner) }
      let!(:staged_request) do
        create(
          :bs_request_with_submit_action,
          review_by_project: staging_project,
          creator: requester,
          description: 'Fixes issue #42',
          target_package: target_package,
          source_package: source_package,
          staging_project: staging_project,
          staging_owner: staging_owner
        )
      end

      context 'with nothing missing' do
        it { is_expected.to have_http_status(:success) }
      end

      context 'with missing check' do
        let!(:repo) { create(:repository, project: staging_project, name: 'standard', architectures: ['local'], required_checks: ['theone']) }

        it { is_expected.to have_http_status(:bad_request) }

        it 'returns correct error' do
          subject
          expect(response.body).to match('Staging Project is not acceptable: testing is not an acceptable state')
        end
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { staging_workflow_project: staging_workflow_project, format: :xml }, body: body }

    let(:staging_workflow_project) { staging_workflow.project.name }
    let!(:other_project) { create(:project, name: "#{project}:other_project") }

    before do
      staging_workflow
    end

    context 'succeeds' do
      let(:body) do
        <<~XML
          <workflow>
            <staging_project>#{project}:Staging:C</staging_project>
            <staging_project>#{project}:other_project</staging_project>
          </workflow>
        XML
      end

      it { expect(subject).to have_http_status(:success) }
      it { expect { subject }.to change(Project, :count).by(1) }
    end

    context 'succeeds as staging manager' do
      let(:staging_manager) { create(:confirmed_user, create_home_project: true) }
      let!(:group_user) { create(:groups_user, group: staging_workflow.managers_group, user: staging_manager) }

      let(:body) do
        <<~XML
               <workflow>
          <staging_project>#{staging_manager.home_project}:Staging:C</staging_project>
               </workflow>
        XML
      end

      before do
        login(staging_manager)
      end

      it { expect(subject).to have_http_status(:success) }
      it { expect { subject }.to change(Project, :count).by(1) }
    end

    context 'fails: project already assigned to a staging workflow' do
      let(:body) do
        <<~XML
          <workflow>
            <staging_project>#{project}:Staging:A</staging_project>
            <staging_project>#{project}:Staging:E</staging_project>
          </workflow>
        XML
      end

      it { expect(subject).to have_http_status(:bad_request) }
      it { expect { subject }.not_to change(Project, :count) }
    end

    context 'fails: body is empty' do
      subject { post :create, params: { staging_workflow_project: staging_workflow_project, format: :xml }, body: nil }

      it { expect(subject).to have_http_status(:bad_request) }
      it { expect { subject }.not_to change(Project, :count) }
    end
  end
end
