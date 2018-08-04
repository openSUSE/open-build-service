require 'rails_helper'
require 'webmock/rspec'

RSpec.describe BsRequestActionWebuiInfosJob, type: :job do
  include ActiveJob::TestHelper
  let(:source_project) { create(:project, name: 'source_project') }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_content: 'b') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_content: 'a') }
  let(:request) do
    create(:bs_request_with_submit_action,
           source_package: source_package,
           target_package: target_package)
  end
  let(:request_action) { request.bs_request_actions.first }

  describe '#perform' do
    context 'for a target package' do
      subject { BsRequestActionWebuiInfosJob.new.perform(request_action) }

      it { is_expected.to include('++++++ somefile.txt') }
    end

    context 'with non existing target project' do
      let(:request) do
        request = build(:bs_request_with_submit_action,
                        source_package: source_package,
                        target_project: 'does-not-exist',
                        target_package: target_package.name)
        request.skip_sanitize
        request.save!
        request
      end
      let(:request_action) { request.bs_request_actions.first }
      subject { BsRequestActionWebuiInfosJob.new.perform(request_action) }

      it { expect { subject }.not_to raise_error }
      it { expect(subject).to eq(nil) }
    end

    context 'with non existing source package' do
      let(:request) do
        request = build(:bs_request_with_submit_action,
                        source_project: 'does-not-exist',
                        source_package: source_package.name,
                        target_package: target_package)
        request.skip_sanitize
        request.save!
        request
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
               source_package: another_source_package,
               target_package: target_package)
      end
      let(:superseding_request_action) { superseding_request.bs_request_actions.first }

      let(:params) do
        {
          cmd: :diff,
          filelimit: 10_000,
          tarlimit: 10_000,
          rev: 0,
          orev: 0,
          oproject: source_project.name,
          opackage: source_package.name
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
