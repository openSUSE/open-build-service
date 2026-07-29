RSpec.describe Group do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }
  let(:another_user) { create(:confirmed_user, login: 'eisenilse') }

  describe 'validations' do
    it { is_expected.to validate_length_of(:title).is_at_least(2).with_message('must have more than two characters') }
    it { is_expected.to validate_length_of(:title).is_at_most(100).with_message('must have less than 100 characters') }
  end

  describe '#involved_projects' do
    let!(:involved_project) { create(:project, maintainer: group) }

    it { expect(group.involved_projects).to contain_exactly(involved_project) }
  end

  describe '#involved_packages' do
    let!(:involved_package) { create(:package_with_maintainer, maintainer: group) }
    let!(:involved_project) { create(:project_with_package, package_name: 'blah', maintainer: group) }

    it { expect(group.involved_packages).to contain_exactly(involved_package) }
  end

  describe '#bs_requests' do
    let(:involved_project) { create(:project, maintainer: group) }
    let!(:incoming_request) { create(:bs_request_with_submit_action, target_project: involved_project, description: 'incoming') }
    let!(:outgoing_request) { create(:bs_request_with_submit_action, source_project: involved_project, description: 'outgoing') }
    let!(:request_with_group_review) { create(:delete_bs_request, target_project: create(:project), review_by_group: group, description: 'group_review') }
    let!(:request_with_project_review) { create(:delete_bs_request, target_project: create(:project), review_by_project: involved_project, description: 'project_review') }
    let!(:request_with_package_review) do
      create(:delete_bs_request, target_project: create(:project), review_by_package: create(:package_with_maintainer, maintainer: group), description: 'package_review')
    end
    let!(:unrelated_request) { create(:bs_request_with_submit_action, source_project: create(:project), description: 'unrelated') }

    it { expect(group.bs_requests.pluck(:description)).to contain_exactly('incoming', 'outgoing', 'group_review', 'project_review', 'package_review') }
  end
end
