require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the BsRequestAction methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe BsRequestActionDelete, vcr: true do
  let(:receiver) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }

  describe '#sourcediff' do
    context 'for project' do
      let(:delete_request) { create(:delete_bs_request, target_project: target_project) }
      subject { delete_request.bs_request_actions.first }

      it { expect { subject.sourcediff }.to raise_error(BsRequestAction::Errors::DiffError) }
    end

    context 'for package' do
      let(:delete_request) { create(:delete_bs_request, target_project: target_project, target_package: target_package) }
      subject { delete_request.bs_request_actions.first }

      it { expect(subject.sourcediff).to include('deleted files:') }
    end

    context 'for repository' do
      let(:delete_request) { create(:delete_bs_request, target_project: target_project, target_repository: 'standard') }
      subject { delete_request.bs_request_actions.first }

      it { expect(subject.sourcediff).to eq('') }
    end
  end
end
