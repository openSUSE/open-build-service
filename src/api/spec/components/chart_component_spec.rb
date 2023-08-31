require 'rails_helper'

RSpec.describe ChartComponent, type: :component do
  let(:source_project) { create(:project, name: 'source_project') }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_content: 'b') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_content: 'a') }
  let(:request) do
    create(:bs_request_with_submit_action,
           source_package: source_package,
           target_package: target_package)
  end
  let(:actions) { request.bs_request_actions }

  let(:fake_build_results) do
    <<-HEREDOC
      <resultlist state="b006a28328744bf1186d2b6fb3006ecb">
        <result project="source_project" repository="openSUSE_Tumbleweed" arch="i586" code="finished" state="finished">
          <status package="source_package" code="unresolvable" />
        </result>
        <result project="source_project" repository="openSUSE_Leap_42.2" arch="x86_64" code="building" state="building">
          <status package="source_package" code="excluded" />
        </result>
      </resultlist>
    HEREDOC
  end

  context 'with build results' do
    before do
      allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_build_results)
    end

    subject { described_class.new(actions: actions) }

    let(:raw_data) { subject.build_results_data }

    context 'get the raw data build results for all the request actions' do
      it { expect(raw_data.size).to be == 2 }
      it { expect(raw_data.pluck(:architecture)).to include('i586') }
    end

    context 'get the list of distinct build results repositories' do
      it { expect(subject.distinct_repositories(raw_data)).to include('openSUSE_Tumbleweed') }
      it { expect(subject.distinct_repositories(raw_data)).to include('openSUSE_Leap_42.2') }
      it { expect(subject.distinct_repositories(raw_data)).not_to include('Debian_Unstable') }
    end
  end
end
