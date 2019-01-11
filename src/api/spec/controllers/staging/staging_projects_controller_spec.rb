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
        get :index, params: { staging_main_project_name: staging_workflow.project.name, format: :xml }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'not existing staging_workflow' do
      before do
        get :index, params: { staging_main_project_name: project_without_staging.name, format: :xml }
      end

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'GET #show' do
    context 'not existing project' do
      before do
        get :show, params: { staging_main_project_name: staging_workflow.project.name, name: 'does-not-exist', format: :xml }
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

      let!(:bs_request) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, staging_project: staging_project))
      end

      let!(:untracked_request) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_project: staging_project))
      end

      let!(:bs_request_to_review) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_project: staging_project, staging_project: staging_project))
      end

      let!(:bs_request_missing_review) do
        create(:bs_request_with_submit_action, request_attributes.merge(creator: user, review_by_user: user, staging_project: staging_project))
      end

      before do
        stub_request(:get, broken_packages_path).and_return(body: broken_packages_backend)
        get :show, params: { staging_main_project_name: staging_workflow.project.name, name: staging_project.name, format: :xml }
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
        end
      end
    end
  end

  describe 'POST #copy' do
    let(:staging_main_project_name) { staging_workflow.project.name }
    let(:original_staging_project_name) { staging_workflow.staging_projects.first.name }
    let(:staging_project_copy_name) { "#{original_staging_project_name}-copy" }
    let(:params) do
      {
        staging_main_project_name: staging_main_project_name,
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
      expect { post :copy, format: :xml, params: params }.to have_enqueued_job(StagingProjectCopyJob).with(staging_main_project_name,
                                                                                                           original_staging_project_name,
                                                                                                           staging_project_copy_name)
    end
  end
end
