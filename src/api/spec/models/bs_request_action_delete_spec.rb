RSpec.describe BsRequestActionDelete, :vcr do
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }

  describe '#sourcediff' do
    context 'for project' do
      subject { delete_request.bs_request_actions.first }

      let(:delete_request) { create(:delete_bs_request, target_project: target_project) }

      it { expect { subject.sourcediff }.to raise_error(BsRequestAction::Errors::DiffError) }
    end

    context 'for package' do
      subject { delete_request.bs_request_actions.first }

      let(:delete_request) { create(:delete_bs_request, target_package: target_package) }

      it { expect(subject.sourcediff).to include('deleted files:') }
    end

    context 'for repository' do
      subject { delete_request.bs_request_actions.first }

      let(:delete_request) { create(:delete_bs_request, target_project: target_project, target_repository: 'standard') }

      it { expect(subject.sourcediff).to eq('') }
    end
  end
end
