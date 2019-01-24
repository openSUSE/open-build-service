require 'rails_helper'

RSpec.describe Webui::RequestHelper do
  let(:target_package) { create(:package) }
  let(:target_project) { target_package.project }
  let(:source_package) { create(:package, :as_submission_source) }

  describe '#new_or_update' do
    context 'for submitting a new package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               target_package: 'does-not-exist-yet',
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row .new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit <small>(new package)</small>') }
      it { expect(new_or_update_request(row)).to be_a(ActiveSupport::SafeBuffer) }
    end

    context 'for releasing a package' do
      let(:bs_request_with_maintenance_release_action) do
        create(:bs_request_with_maintenance_release_action,
               target_package: target_package,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row.new(bs_request_with_maintenance_release_action) }

      it { expect(new_or_update_request(row)).to eq('release') }
    end

    context 'for submitting an existing package' do
      let(:bs_request_with_submit_action) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package)
      end
      let(:row) { BsRequest::DataTable::Row.new(bs_request_with_submit_action) }

      it { expect(new_or_update_request(row)).to eq('submit') }
    end
  end

  describe '#calculate_filename' do
    let(:filename) { 'apache2' }

    context 'for deleted files' do
      let(:file_element) do
        { state: 'deleted' }.with_indifferent_access
      end

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
    end

    context 'for added files' do
      let(:file_element) do
        { state: 'added' }.with_indifferent_access
      end

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
    end

    context 'for changed files' do
      let(:file_element) do
        { state: 'changed', old: { name: filename } }.with_indifferent_access
      end
      let(:new_filename) { 'apache3' }

      it { expect(calculate_filename(filename, file_element)).to eq(filename) }
      it { expect(calculate_filename(new_filename, file_element)).to eq("#{filename} -> #{new_filename}") }
    end
  end

  context 'source diffs' do
    let(:source_diff) do
      {
        'old' => {
          'project' => 'home:Admin',
          'package' => 'obs-server',
          'rev' => 12
        },
        'new' => {
          'project' => 'home:tux',
          'package' => 'koji',
          'rev' => 13
        }
      }
    end

    describe '#diff_label' do
      it { expect(diff_label(source_diff['old'])).to eq('home:Admin / obs-server (rev 12)') }
    end

    describe '#diff_data' do
      context "when it's a delete request" do
        subject { diff_data(:delete, source_diff) }

        it { is_expected.to match(project: 'home:Admin', package: 'obs-server', rev: 12) }
      end

      context "when it's not a delete request" do
        subject { diff_data(:submit, source_diff) }

        it { is_expected.to match(project: 'home:tux', package: 'koji', rev: 13) }
      end
    end
  end
end
