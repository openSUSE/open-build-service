require 'rails_helper'
require Rails.root.join('db/data/20200421121610_backfill_notified_projects.rb')

RSpec.describe BackfillNotifiedProjects, type: :migration, vcr: true do
  describe 'up' do
    let(:source_project) { create(:project, name: 'source_project') }
    let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project) }
    let(:target_project) { create(:project, name: 'target_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:target_project_2) { create(:project, name: 'target_project_2') }
    let(:target_package_2) { create(:package, name: 'target_package_2', project: target_project_2) }

    let(:bs_request_action_1) { create(:bs_request_action_add_maintainer_role, target_project: target_project, source_package: source_package) }
    let(:bs_request_action_2) do
      create(:bs_request_action_submit,
             source_project: source_project, source_package: source_package, target_project: target_project, target_package: target_package)
    end
    let(:bs_request_action_3) do
      create(:bs_request_action_submit,
             source_project: source_project, source_package: source_package, target_project: target_project_2, target_package: target_package_2)
    end

    let(:bs_request_with_submit_action) do
      create(:bs_request_with_submit_action, bs_request_actions: [bs_request_action_1, bs_request_action_2, bs_request_action_3])
    end
    let(:user_review) { create(:user_review, bs_request: bs_request_with_submit_action) }
    let(:comment_project) { create(:comment_project) }
    let(:comment_package) { create(:comment_package) }
    let(:comment_request) { create(:comment_request) }

    before do
      create(:notification, :request_state_change, notifiable: bs_request_with_submit_action)
      create(:notification, :review_wanted, notifiable: user_review.bs_request)
      create(:notification, :comment_for_project, notifiable: comment_project)
      create(:notification, :comment_for_package, notifiable: comment_package)
      create(:notification, :comment_for_request, notifiable: comment_request)

      BackfillNotifiedProjects.new.up
    end

    it 'backfills the notifications_projects table with all projects from existing notifications' do
      expect(NotifiedProject.pluck(:project_id)).to eq([
        bs_request_with_submit_action.target_project_objects.distinct.map(&:id),
        user_review.bs_request.target_project_objects.distinct.map(&:id),
        comment_project.commentable.id,
        comment_package.commentable.project_id,
        comment_request.commentable.target_project_objects.distinct.map(&:id)
      ].flatten!)
    end
  end
end
