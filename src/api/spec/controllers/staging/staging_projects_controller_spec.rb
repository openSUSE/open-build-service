require 'rails_helper'

RSpec.describe Staging::StagingProjectsController, type: :controller, vcr: true do
  render_views

  let(:user) { create(:confirmed_user, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:project_without_staging) { create(:project, name: 'foo_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }

  describe 'GET #index' do
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

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'GET #show' do
    context 'not existing project' do
      before do
        get :show, params: { staging_workflow_project: staging_workflow.project.name, name: 'does-not-exist', format: :xml }
      end

      it { expect(response).to have_http_status(:not_found) }
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
        get :show, params: { staging_workflow_project: staging_workflow.project.name, name: staging_project.name, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
      it 'returns the staging_project name xml' do
        assert_select 'staging_project' do
          assert_select 'staged_requests', 1 do
            assert_select 'entry', 3
          end
          assert_select 'untracked_requests', 1 do
            assert_select 'entry', 1
          end
          assert_select 'requests_to_review', 1 do
            assert_select 'entry', 2
          end
          assert_select 'missing_reviews', 1 do
            assert_select 'entry', 1
          end
          assert_select 'broken_packages', 1 do
            assert_select 'entry', 2
          end
          assert_select 'history', 1
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
      login(user)
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

    let(:params) { { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name } }

    before do
      login user
      staging_workflow
    end

    context 'when staging project is not ready to be accepted' do
      subject! do
        post :accept, params: params, format: :xml
      end

      it { is_expected.to have_http_status(:bad_request) }
      it { expect(response.body).to match('Staging project is not in state acceptable.') }
    end

    context 'when project is in state acceptable' do
      let(:requester) { create(:confirmed_user, login: 'requester') }
      let(:target_project) { create(:project, name: 'target_project') }
      let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
      let(:target_package) { create(:package, name: 'target_package', project: target_project) }
      let(:source_package) { create(:package, name: 'source_package', project: source_project) }
      let!(:user_relationship) { create(:relationship, project: target_project, user: user) }
      let!(:staged_request_1) do
        create(
          :bs_request_with_submit_action,
          state: :new,
          creator: requester,
          description: 'Fixes issue #42',
          target_package: target_package,
          source_package: source_package,
          staging_project: staging_project,
          staging_owner: user
        )
      end

      before do
        allow(StagingProjectAcceptJob).to receive(:perform_later)
        User.current = user
      end

      subject do
        post :accept, params: params, format: :xml
      end

      it { is_expected.to have_http_status(:success) }
      it "starts the 'accept' job for the staging projects" do
        subject
        expect(StagingProjectAcceptJob).to have_received(:perform_later).with(project_id: staging_project.id, user_login: user.login)
      end
    end
  end

  describe 'POST #create' do
    let(:staging_workflow_project) { staging_workflow.project.name }
    let!(:other_project) { create(:project, name: "#{project}:other_project") }

    before do
      login(user)
      staging_workflow
    end

    subject { post :create, params: { staging_workflow_project: staging_workflow_project, format: :xml }, body: body }

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
