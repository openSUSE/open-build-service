require 'rails_helper'

RSpec.describe Status::Report, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:checkable) }

    context 'for bs requests' do
      let(:source_project) { create(:project_with_package) }
      let(:target_project) { create(:project_with_package) }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               source_project: source_project,
               source_package: source_project.packages.first,
               target_project: target_project,
               target_package: target_project.packages.first)
      end
      let(:status_report) { create(:status_report, checkable: bs_request) }

      it { expect(status_report).not_to validate_presence_of(:uuid) }
    end

    context 'for repositories' do
      let(:status_report) { create(:status_report, checkable: create(:repository)) }

      it { expect(status_report).to validate_presence_of(:uuid) }
    end
  end
end
