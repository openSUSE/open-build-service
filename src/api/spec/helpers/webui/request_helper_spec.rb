require 'rails_helper'

RSpec.describe Webui::RequestHelper do
  let(:target_package) { create(:package) }
  let(:target_project) { target_package.project }
  let(:source_package) { create(:package) }
  let(:source_project) { source_package.project }

  describe '#new_or_update' do
    context 'for submitting a new package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               target_package: 'does-not-exist-yet',
               source_project: source_project,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row .new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit <small>(new package)</small>') }
      it { expect(new_or_update_request(row)).to be_a(ActiveSupport::SafeBuffer) }
    end

    context 'for releasing a package' do
      let(:bs_request_with_maintenance_release_action) do
        create(:bs_request_with_maintenance_release_action,
               target_project: target_project,
               target_package: target_package,
               source_project: source_project,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row .new(bs_request_with_maintenance_release_action) }

      it { expect(new_or_update_request(row)).to eq('release') }
    end

    context 'for submitting an existing package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               target_package: target_package,
               source_project: source_project,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row .new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit') }
    end
  end
end
