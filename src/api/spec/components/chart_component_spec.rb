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
        <result project="source_project" repository="openSUSE_Leap_42.2" arch="s390" code="finished" state="succeeded">
          <status package="source_package" code="excluded" />
        </result>
      </resultlist>
    HEREDOC
  end

  let(:fake_raw_data) do
    [
      { architecture: 'x86_64', repository: 'openSUSE_Leap_42.2', status: 'excluded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 'i586', repository: 'openSUSE_Tumbleweed', status: 'unresolvable', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 's390', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 'x86_64', repository: 'Debian_Stable', status: 'succeeded', package_name: 'source_package', project_name: 'source_project' },
      { architecture: 's390', repository: 'openSUSE_Tumbleweed', status: 'building', package_name: 'source_package', project_name: 'source_project' }
    ]
  end

  subject { described_class.new(actions: actions) }

  before do
    allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_build_results)
  end

  context 'with build results' do
    let(:raw_data) { subject.build_results_data }

    context 'get the raw data build results for all the request actions' do
      it { expect(raw_data.size).to eq(3) }
      it { expect(raw_data.pluck(:architecture)).to include('i586') }
    end

    context 'get the list of distinct build results repositories' do
      it { expect(subject.distinct_repositories(raw_data)).to include('openSUSE_Tumbleweed') }
      it { expect(subject.distinct_repositories(raw_data)).to include('openSUSE_Leap_42.2') }
      it { expect(subject.distinct_repositories(raw_data)).not_to include('Debian_Unstable') }
    end
  end

  context 'building data for the chart' do
    let(:chart_data) { subject.chart_data(fake_raw_data) }

    context 'produce the dataset for the chart' do
      it { expect(chart_data.size).to eq(4) }
      it { expect(chart_data.pluck(:name)).to include('Published') }
      it { expect(chart_data.pluck(:data)).to include({ 'Debian_Stable' => 2 }) }
      it { expect(chart_data.pluck(:data)).to include({ 'openSUSE_Leap_42.2' => 1 }) }
    end
  end
end
