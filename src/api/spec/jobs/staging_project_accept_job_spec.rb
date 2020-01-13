require 'rails_helper'
require 'webmock/rspec'

RSpec.describe StagingProjectAcceptJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
    let(:managers_group) { create(:group) }
    let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: user.home_project, managers_group: managers_group) }
    let(:staging_project) { staging_workflow.staging_projects.first }
    let!(:package) { create(:package_with_file, name: 'package_with_file', project: staging_project) }

    let(:target_project) { create(:project, name: 'target_project') }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }

    let(:requester) { create(:confirmed_user, login: 'requester') }
    let(:target_package_2) { create(:package, name: 'target_package_2', project: target_project) }
    let(:staged_request) do
      create(
        :bs_request_with_submit_action,
        state: :new,
        creator: requester,
        description: "Request for package #{target_package}",
        target_package: target_package,
        source_package: source_package,
        staging_project: staging_project,
        staging_owner: user
      )
    end
    let(:staged_request_with_by_project_review) do
      create(
        :bs_request_with_submit_action,
        creator: requester,
        description: "Request for package #{target_package_2}",
        target_package: target_package_2,
        source_package: source_package,
        staging_project: staging_project,
        review_by_project: staging_project.name,
        staging_owner: user
      )
    end

    before do
      User.session = user
      staged_request
      staged_request_with_by_project_review
    end

    subject { StagingProjectAcceptJob.perform_now(project_id: staging_project.id, user_login: user.login) }

    context "when the staging project is in 'acceptable' state" do
      let!(:project_log_entry_comment_for_project) do
        create(:project_log_entry_comment_for_project, project: staging_project, user_name: user.login)
      end
      let!(:project_log_entry_staging_project_created) do
        create(:project_log_entry_staging_project_created, project: staging_project, user_name: user.login)
      end
      let!(:project_log_entry_staged_request) do
        create(:project_log_entry_staged_request,
               project: staging_project,
               user_name: user.login,
               package_name: target_package.title,
               bs_request: staged_request)
      end
      let!(:project_log_entry_unstaged_request) do
        create(:project_log_entry_unstaged_request,
               project: staging_project,
               user_name: user.login,
               package_name: target_package.title,
               bs_request: staged_request)
      end
      let!(:user_relationship) { create(:relationship, project: target_project, user: user) }

      context 'staging project should be accepted' do
        before do
          subject
          # Ensure we test the current state.
          staging_project.send(:clear_memoized_data)
        end

        it { expect(staging_project.overall_state).to eq(:empty) }
        it { expect(staging_project.reload.packages).to contain_exactly(package) }
        it { expect(staged_request.reload.state).to eq(:accepted) }
        it { expect(staged_request_with_by_project_review.reload.state).to eq(:accepted) }
        it { expect(staged_request_with_by_project_review.reviews.where.not(state: 'accepted')).not_to exist }
      end

      context 'should remove staging project log entries' do
        it { expect { subject }.to change { staging_project.project_log_entries.count }.from(4).to(1) }
        it { expect { subject }.to change { staging_project.project_log_entries.staging_history.count }.from(3).to(0) }
      end
    end

    context 'when the staging project has missing reviews' do
      let!(:user_relationship) { create(:relationship, project: target_project, user: user) }
      let(:target_package_3) { create(:package, name: 'target_package_3', project: target_project) }
      let!(:open_staged_request) do
        create(
          :bs_request_with_submit_action,
          description: "Request for package #{target_package_3}",
          creator: requester,
          target_package: target_package_3,
          source_package: source_package,
          staging_project: staging_project,
          staging_owner: user,
          review_by_user: user
        )
      end

      it { expect { subject }.to raise_error PostRequestNoPermission }
    end

    context 'when the user has no permissions for the target' do
      it { expect { subject }.to raise_error PostRequestNoPermission }
    end
  end
end
