require 'rails_helper'
require 'webmock/rspec'

RSpec.describe LocalBuildStatistic::ForPackage do
  let(:fake_statistics_result) do
    <<-HEREDOC
      <buildstatistics>
        <disk>
          <usage>
            <size unit="M">491</size>
            <io_requests>4900</io_requests>
            <io_sectors>826498</io_sectors>
          </usage>
        </disk>
        <memory>
          <usage>
            <size unit="M">106</size>
          </usage>
        </memory>
        <times>
          <total>
            <time unit="s">107</time>
          </total>
          <preinstall>
            <time unit="s">18</time>
          </preinstall>
          <install>
            <time unit="s">24</time>
          </install>
          <main>
            <time unit="s">4</time>
          </main>
          <download>
            <time unit="s">4</time>
          </download>
        </times>
        <download>
          <size unit="k">7548</size>
          <binaries>4</binaries>
          <cachehits>103</cachehits>
        </download>
      </buildstatistics>
    HEREDOC
  end

  describe '#statistic' do
    let(:results) { local_statistics.results }
    let(:local_statistics) do
      LocalBuildStatistic::ForPackage.new(package: 'fake_package', project: 'fake_project', repository: 'SLE_12_SP2', architecture: 'x86_64')
    end

    context 'with results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:statistics).and_return(fake_statistics_result)
      end

      it { expect(results.disk).to have_attributes(size: '491', unit: 'M', io_requests: '4900', io_sectors: '826498') }
      it { expect(results.memory).to have_attributes(size: '106', unit: 'M') }
      it 'related with times (total, install, preinstall, main)' do
        expect(results.times).to have_attributes(total: '107', total_unit: 's',
                                                   preinstall: '18', preinstall_unit: 's',
                                                   install: '24', install_unit: 's',
                                                   main: '4', main_unit: 's')
      end
    end

    context 'without results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:statistics).and_return('<buildstatistics></buildstatistics>')
      end

      it { expect(results).to be_nil }
    end

    context 'with backend error' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:statistics).and_raise(Backend::Error)
      end

      it { expect(results).to be_nil }
    end
  end
end
