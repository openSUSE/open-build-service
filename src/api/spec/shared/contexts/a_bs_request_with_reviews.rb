RSpec.shared_context 'a BsRequest with reviews' do
  let(:reviewer) { create(:confirmed_user, login: 'reviewer') }
  let(:group) { create(:group, title: 'request_reviewer') }
  let(:source_project) { create(:project_with_package, name: 'source_project') }
  let(:target_project) { create(:project_with_package, name: 'target_project') }
  let!(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_project.packages.first,
           source_package: source_project.packages.first,
           review_by_user: reviewer)
  end
end
