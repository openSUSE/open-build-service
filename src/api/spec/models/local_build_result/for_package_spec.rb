require 'rails_helper'
require 'webmock/rspec'

RSpec.describe LocalBuildResult::ForPackage, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tome') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:fake_multibuild_results_with_all_excluded) do
    Buildresult.new(
      '<resultlist state="b006a28328744bf1186d2b6fb3006ecb">
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="i586" code="finished" state="finished">
          <status package="test_package" code="excluded" />
          <status package="test_package:test_package-source" code="excluded" />
        </result>
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="x86_64" code="building" state="building">
          <status package="test_package" code="excluded" />
          <status package="test_package:test_package-source" code="excluded" />
        </result>
        <result project="home:tom" repository="openSUSE_Leap_42.2" arch="x86_64" code="finished" state="finished">
          <status package="test_package" code="excluded" />
          <status package="test_package:test_package-source" code="excluded" />
        </result>
      </resultlist>'
    )
  end
  let(:fake_multibuild_results_with_some_excluded) do
    Buildresult.new(
      '<resultlist state="b006a28328744bf1186d2b6fb3006ecb">
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="i586" code="finished" state="finished">
          <status package="test_package" code="unresolvable" />
          <status package="test_package:test_package-source" code="excluded" />
        </result>
        <result project="home:tom" repository="openSUSE_Tumbleweed" arch="x86_64" code="building" state="building">
          <status package="test_package" code="excluded" />
          <status package="test_package:test_package-source" code="broken">
            <details>fake details</details>
          </status>
        </result>
        <result project="home:tom" repository="openSUSE_Leap_42.2" arch="x86_64" code="finished" state="finished">
          <status package="test_package" code="succeeded" />
          <status package="test_package:test_package-source" code="excluded" />
        </result>
      </resultlist>'
    )
  end

  describe '#buildresults' do
    let(:test_package) { results['test_package'] }
    let(:test_package_source) { results['test_package:test_package-source'] }
    let(:results) { local_build_result.results }
    let(:excluded_counter) { local_build_result.excluded_counter }

    context 'with "show_all" equal false' do
      let(:local_build_result) { LocalBuildResult::ForPackage.new(package: package, project: home_project, show_all: false) }

      context 'when all entries are excluded' do
        before do
          allow(Buildresult).to receive(:find).and_return(fake_multibuild_results_with_all_excluded)
        end

        it { expect(test_package).to eq([]) }
        it { expect(test_package_source).to eq([]) }
        it { expect(excluded_counter).to eq(6) }
      end

      context 'when some entries are exluded' do
        before do
          allow(Buildresult).to receive(:find).and_return(fake_multibuild_results_with_some_excluded)
        end

        it { expect(excluded_counter).to eq(3) }

        it { expect(test_package.length).to eq(2) }
        it { expect(test_package.map(&:repository)).to eq(['openSUSE_Leap_42.2', 'openSUSE_Tumbleweed']) }
        it { expect(test_package.map(&:architecture)).to eq(['x86_64', 'i586']) }
        it { expect(test_package.map(&:code)).to eq(['succeeded', 'unresolvable']) }
        it { expect(test_package.map(&:state)).to eq(['finished', 'finished']) }
        it { expect(test_package.map(&:details)).to eq([nil, nil]) }

        it { expect(test_package_source.length).to eq(1) }
        it { expect(test_package_source.first.repository).to eq('openSUSE_Tumbleweed') }
        it { expect(test_package_source.first.architecture).to eq('x86_64') }
        it { expect(test_package_source.first.code).to eq('broken') }
        it { expect(test_package_source.first.state).to eq('building') }
        it { expect(test_package_source.first.details).to eq('fake details') }
      end
    end

    context 'with "show_all" equal true' do
      let(:local_build_result) { LocalBuildResult::ForPackage.new(package: package, project: home_project, show_all: true) }

      before do
        allow(Buildresult).to receive(:find).and_return(fake_multibuild_results_with_some_excluded)
      end

      it { expect(excluded_counter).to eq(0) }

      it { expect(test_package.length).to eq(3) }
      it { expect(test_package.map(&:repository)).to eq(['openSUSE_Leap_42.2', 'openSUSE_Tumbleweed', 'openSUSE_Tumbleweed']) }
      it { expect(test_package.map(&:architecture)).to eq(['x86_64', 'i586', 'x86_64']) }
      it { expect(test_package.map(&:code)).to eq(['succeeded', 'unresolvable', 'excluded']) }
      it { expect(test_package.map(&:state)).to eq(['finished', 'finished', 'building']) }
      it { expect(test_package.map(&:details)).to eq([nil, nil, nil]) }

      it { expect(test_package_source.length).to eq(3) }
      it { expect(test_package_source.map(&:repository)).to eq(['openSUSE_Leap_42.2', 'openSUSE_Tumbleweed', 'openSUSE_Tumbleweed']) }
      it { expect(test_package_source.map(&:architecture)).to eq(['x86_64', 'i586', 'x86_64']) }
      it { expect(test_package_source.map(&:code)).to eq(['excluded', 'excluded', 'broken']) }
      it { expect(test_package_source.map(&:state)).to eq(['finished', 'finished', 'building']) }
      it { expect(test_package_source.map(&:details)).to eq([nil, nil, 'fake details']) }
    end
  end
end
