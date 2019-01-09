RSpec.shared_context 'a BsRequest with reviews' do
  let(:reviewer) { create(:confirmed_user, login: 'reviewer') }
  let(:group) { create(:group, title: 'request_reviewer') }
  let(:source_project) { create(:project_with_package, name: 'source_project') }
  let(:target_project) { create(:project_with_package, name: 'target_project') }
  let(:target_package) { target_project.packages.first }
  let!(:bs_request) do
    create(:bs_request_with_submit_action,
           target_project: target_project,
           target_package: target_package,
           source_project: source_project,
           source_package: source_project.packages.first,
           review_by_user: reviewer.login)
  end
end
