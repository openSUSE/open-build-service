RSpec.shared_context 'a project with maintenance statistics' do
  let(:user) { create(:confirmed_user) }
  let!(:project) do
    travel_to(10.days.ago) do
      create(
        :project_with_repository,
        name: 'ProjectWithRepo'
      )
    end
  end
  let!(:bs_request) do
    travel_to(9.days.ago) do
      create(:bs_request_with_maintenance_release_action,
             source_project: project,
             state: :review)
    end
  end
  let!(:history_element_request_accepted) do
    travel_to(7.days.ago) do
      create(
        :history_element_request_accepted,
        request: bs_request,
        user: user
      )
    end
  end
  let!(:review) do
    travel_to(6.days.ago) do
      create(
        :review,
        bs_request: bs_request,
        by_user: user.login,
        state: :declined
      )
    end
  end
  let!(:history_element_review_declined) do
    travel_to(5.days.ago) do
      create(
        :history_element_review_declined,
        review: review,
        user: user
      )
    end
  end

  let(:package) { create(:package_with_file, project: project) }
  let!(:issue_tracker) { create(:issue_tracker) }
  let!(:issue) { travel_to(4.days.ago) { create(:issue, issue_tracker_id: issue_tracker.id) } }
  let!(:package_issue) { create(:package_issue, package: package, issue: issue) }
end
