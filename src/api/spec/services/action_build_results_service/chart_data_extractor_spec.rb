RSpec.describe ActionBuildResultsService::ChartDataExtractor do
  describe '#call' do
    subject { described_class.new(actions: actions).call }

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

    let(:fake_empty_results) do
      <<-HEREDOC
        <resultlist>
        </resultlist>
      HEREDOC
    end

    context 'with build results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_build_results)
      end

      it { expect(subject.size).to eq(3) }
      it { expect(subject.pluck(:architecture)).to include('i586') }
    end

    context 'with no results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(fake_empty_results)
      end

      it { expect(subject).to eq([]) }
    end

    context 'with no actions' do
      let(:actions) { nil }

      it { expect(subject).to eq([]) }
    end
  end
end
