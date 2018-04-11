# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe BsRequestActionWebuiInfosJob, type: :job, vcr: true do
  include ActiveJob::TestHelper
  let(:source_project) { create(:project, name: 'source_project') }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_content: 'b') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_content: 'a') }
  let(:request) do
    create(:bs_request_with_submit_action,
           source_project: source_project.name,
           source_package: source_package.name,
           target_project: target_project.name,
           target_package: target_package.name)
  end
  let(:request_action) { request.bs_request_actions.first }

  describe '#perform' do
    context 'for a target package' do
      let(:diff_result) do
        <<-DIFF
          ++++++ somefile.txt
          --- somefile.txt
          +++ somefile.txt
          @@ -1,1 +1,1 @@
          -a
          \\ No newline at end of file
          +b
          \\ No newline at end of file
        DIFF
      end

      subject { BsRequestActionWebuiInfosJob.new.perform(request_action) }

      it 'creates the diff' do
        # gsub because of rubocop Lint/Syntax error when using <<~
        # we need to upgrade to use ruby 2.5 parser first
        expect(subject).to include(diff_result.gsub('          ', ''))
      end
    end

    context 'with non existing target project' do
      let(:request) do
        create(:bs_request_with_submit_action,
               source_project: source_project.name,
               source_package: source_package.name,
               target_project: 'does-not-exist',
               target_package: target_package.name)
      end
      let(:request_action) { request.bs_request_actions.first }
      subject { BsRequestActionWebuiInfosJob.new.perform(request_action) }

      it { expect { subject }.not_to raise_error }
      it { expect(subject).to eq(nil) }
    end

    context 'with non existing source package' do
      let(:request) do
        create(:bs_request_with_submit_action,
               source_project: source_project.name,
               source_package: 'does-not-exist',
               target_project: target_project.name,
               target_package: target_package.name)
      end
      let(:request_action) { request.bs_request_actions.first }
      subject { BsRequestActionWebuiInfosJob.new.perform(request_action) }

      it { expect { subject }.not_to raise_error }
      it { expect(subject).to eq(nil) }
    end

    context 'for a superseded request' do
      let(:another_source_project) { create(:project, name: 'another_source_project') }
      let(:another_source_package) { create(:package_with_file, name: 'another_source_package', project: another_source_project, file_content: 'c') }
      let(:superseding_request) do
        create(:bs_request_with_submit_action,
               source_project: another_source_project.name,
               source_package: another_source_package.name,
               target_project: target_project.name,
               target_package: target_package.name)
      end
      let(:superseding_request_action) { superseding_request.bs_request_actions.first }

      let(:params) do
        {
          cmd:       :diff,
          filelimit: 10_000,
          tarlimit:  10_000,
          rev:       0,
          orev:      0,
          oproject:  source_project.name,
          opackage:  source_package.name
        }
      end

      let(:path) { "#{CONFIG['source_url']}/source/#{another_source_project}/#{another_source_package}?#{params.to_param}" }
      before do
        request.update_attributes(superseded_by: superseding_request.number, state: :superseded)
      end

      subject! { BsRequestActionWebuiInfosJob.new.perform(superseding_request_action) }

      # The Job always returns the result for the target package, therefore we need check for the request to be made
      it { expect(a_request(:post, path)).to have_been_made.once }
    end
  end
end
