RSpec.describe ActionBuildResultsService::ChartDataExtractor do
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

  describe '#call' do
    subject { described_class.new(actions: actions).call }

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

    let(:build_results_with_info) do
      <<-HEREDOC
        <resultlist state="89404e94496aebc9a61c552c7b0eea78">
          <result project="home:Iggy" repository="xUbuntu_25.04" arch="x86_64" code="finished" state="finished">
            <status package="vlogger" code="succeeded"/>
            <info package="vlogger">
              <buildtype>dsc</buildtype>
            </info>
          </result>
          <result project="home:Iggy" repository="Debian_12" arch="i586" code="finished" state="finished">
            <status package="vlogger" code="disabled"/>
          </result>
          <result project="home:Iggy" repository="Debian_12" arch="x86_64" code="finished" state="finished">
            <status package="vlogger" code="succeeded"/>
            <info package="vlogger">
              <buildtype>dsc</buildtype>
            </info>
          </result>
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

    context 'for non-rpm builds' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_return(build_results_with_info)
      end

      it 'returns correct buildtype in the response' do
        expect(subject.any? { |h| h[:buildtype] == 'dsc' }).to be true
      end
    end
  end

  describe '#sort_build_results' do
    subject { described_class.new(actions: actions).send(:sort_build_results, source_build_results, target_build_results) }

    let(:source_build_results) do
      [{ repository: 'openSUSE_Tumbleweed' }, { repository: 'Debian_9.0' }]
    end
    let(:target_build_results) do
      [{ repository: '15.5' }, { repository: 'Debian_12' }, { repository: 'Debian_12' }, { repository: 'openSUSE_Tumbleweed' }]
    end

    it 'returns a sorted list' do
      expect(subject).to eq([{ repository: 'openSUSE_Tumbleweed' }, { repository: 'Debian_9.0' }])
    end
  end
end
