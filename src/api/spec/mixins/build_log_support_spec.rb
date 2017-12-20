require 'webmock/rspec'
require 'rails_helper'

RSpec.describe BuildLogSupport do
  let(:instance_with_build_log_support) do
    fake_instance = double('Fake Instance with BuildLogSupport')
    fake_instance.extend(BuildLogSupport)
    allow(fake_instance).to receive(:logger).and_return(Rails.logger)
    fake_instance
  end

  describe 'log chunks' do
    let(:build_log) do
      '[ 3567s]   CC [M]  fs/squashfs/decompressor_single.o
[ 3569s]   CC [M]  fs/squashfs/xattr.o
[ 3569s]   CC [M]  fs/squashfs/xattr_id.o
[ 3570s]   CC [M]  fs/squashfs/lz4_wrapper.o'
    end

    before do
      path = "#{CONFIG['source_url']}/build/project_1/repository_1/architecture_1/package_1/_log?end=65536&nostream=1&start=0"
      stub_request(:get, path).and_return(body: build_log)
    end

    describe '#raw_log_chunk' do
      subject { instance_with_build_log_support.raw_log_chunk('project_1', 'package_1', 'repository_1', 'architecture_1', 0, 65536) }

      it { is_expected.to eq(build_log) }
    end

    describe '#get_log_chunk' do
      subject { instance_with_build_log_support.get_log_chunk('project_1', 'package_1', 'repository_1', 'architecture_1', 0, 65536) }

      context 'without special characters' do
        it { is_expected.to eq(build_log) }
      end

      context 'with special characters' do
        let(:build_log) do
          # Tested some characters with ord < 32, \n and \r
          "\u000A\u000D\u000F\n\r"
        end

        it { is_expected.to eq("\r\r\r\r") }
      end
    end
  end

  describe '#get_size_of_log' do
    let(:path) { "#{CONFIG['source_url']}/build/project_1/repository_1/architecture_1/package_1/_log?view=entry" }

    subject { instance_with_build_log_support.get_size_of_log('project_1', 'package_1', 'repository_1', 'architecture_1') }

    context 'with size' do
      before do
        stub_request(:get, path).and_return(body: '<directory><entry size="1"/></directory>')
      end

      it { is_expected.to eq(1) }
    end

    context 'without size' do
      before do
        stub_request(:get, path).and_return(body: '<directory></directory>')
      end

      it { is_expected.to eq(0) }
    end
  end

  describe '#get_job_status' do
    before do
      path = "#{CONFIG['source_url']}/build/project_1/repository_1/architecture_1/package_1/_jobstatus"
      stub_request(:get, path).and_return(body: 'failed')
    end

    subject { instance_with_build_log_support.get_job_status('project_1', 'package_1', 'repository_1', 'architecture_1') }

    it { is_expected.to eq('failed') }
  end

  describe '#get_status' do
    let(:path) { "#{CONFIG['source_url']}/build/project_1/_result?arch=architecture_1&package=package_1&repository=repository_1&view=status" }

    subject { instance_with_build_log_support.get_status('project_1', 'package_1', 'repository_1', 'architecture_1') }

    context 'with a code' do
      let(:status_body) do
        "<resultlist>
          <result project=\"project_1\" repository=\"repository_1\" arch=\"architecture_1\">
             <status package=\"package_1\" code=\"failed\" />
          </result>
        </resultlist>"
      end

      before do
        stub_request(:get, path).and_return(body: status_body)
      end

      it { is_expected.to eq('failed') }
    end

    context 'without a code' do
      let(:status_body_without_code) do
        "<resultlist>
          <result project=\"project_1\" repository=\"repository_1\" arch=\"architecture_1\" />
        </resultlist>"
      end

      before do
        stub_request(:get, path).and_return(body: status_body_without_code)
      end

      it { is_expected.to eq('') }
    end
  end
end
