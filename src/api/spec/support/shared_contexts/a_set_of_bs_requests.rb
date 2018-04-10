# frozen_string_literal: true
RSpec.shared_context 'a set of bs requests' do
  # Set 1
  let!(:user) { create(:confirmed_user, login: 'tom') }

  let!(:source_project) { create(:project_with_package) }
  let!(:source_package) { source_project.packages.first }
  let!(:target_project) { create(:project_with_package, name: 'a_target_project') }
  let!(:target_package) { target_project.packages.first }

  let!(:request1) do
    create(:bs_request_with_submit_action,
           creator: user,
           priority: 'critical',
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end
  let!(:request2) do
    create(:bs_request_with_submit_action,
           created_at: 2.days.ago,
           creator: user,
           source_project: source_project,
           source_package: source_package,
           target_project: target_project,
           target_package: target_package)
  end
  let!(:bs_requests) do
    create_list(:bs_request_with_submit_action,
                8,
                created_at: 1.day.ago,
                creator: user,
                source_project: source_project,
                source_package: source_package,
                target_project: target_project,
                target_package: target_package)
  end

  # Set 2
  let!(:user2) { create(:confirmed_user, login: 'jerry') }

  let!(:source_project2) { create(:project_with_package) }
  let!(:source_package2) { source_project2.packages.first }
  let!(:target_project2) { create(:project_with_package, name: 'b_target_project') }
  let!(:target_package2) { target_project2.packages.first }

  let!(:request3) do
    create(:bs_request_with_submit_action,
           creator: user2,
           priority: 'critical',
           source_project: source_project2,
           source_package: source_package2,
           target_project: target_project2,
           target_package: target_package2)
  end

  # for testing ordering by composite column target_project, target_package
  let!(:request4) do
    create(:bs_request_with_submit_action,
           created_at: 1.day.ago,
           creator: user,
           source_project: source_project,
           source_package: source_package,
           target_project: target_project2,
           target_package: target_package2)
  end
end
