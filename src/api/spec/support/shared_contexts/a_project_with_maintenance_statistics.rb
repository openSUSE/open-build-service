# frozen_string_literal: true

RSpec.shared_context 'a project with maintenance statistics' do
  let(:user) { create(:confirmed_user) }
  let!(:project) do
    create(
      :project_with_repository,
      name: 'ProjectWithRepo',
      created_at: 10.days.ago
    )
  end
  let!(:bs_request) do
    create(
      :bs_request,
      source_project: project,
      type: 'maintenance_release',
      created_at: 9.days.ago
    )
  end
  let!(:history_element_request_accepted) do
    create(
      :history_element_request_accepted,
      request: bs_request,
      user: user,
      created_at: 7.days.ago
    )
  end
  let!(:review) do
    create(
      :review,
      bs_request: bs_request,
      by_user: user.login,
      created_at: 6.days.ago,
      state: :declined
    )
  end
  let!(:history_element_review_declined) do
    create(
      :history_element_review_declined,
      review: review,
      user: user,
      created_at: 5.days.ago
    )
  end

  let(:package) { create(:package_with_file, project: project) }
  let!(:issue_tracker) { create(:issue_tracker) }
  let!(:issue) { create(:issue, issue_tracker_id: issue_tracker.id, created_at: 4.days.ago) }
  let!(:package_issue) { create(:package_issue, package: package, issue: issue) }
end
