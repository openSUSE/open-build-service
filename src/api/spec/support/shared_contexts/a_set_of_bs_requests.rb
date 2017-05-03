RSpec.shared_context 'a set of bs requests' do
  let!(:user) { create(:confirmed_user, login: "tom") }

  let!(:source_project) { create(:project_with_package) }
  let!(:source_package) { source_project.packages.first }
  let!(:target_project) { create(:project_with_package) }
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
                9,
                created_at: 1.day.ago,
                creator: user,
                source_project: source_project,
                source_package: source_package,
                target_project: target_project,
                target_package: target_package)
  end
end
