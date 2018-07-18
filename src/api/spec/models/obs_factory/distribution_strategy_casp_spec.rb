require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::DistributionStrategyCasp do
  let(:project) { create(:project, name: 'SUSE:SLE-12-SP2:Update:Products:CASP3') }
  let(:distribution) { ObsFactory::Distribution.new(project) }
  let(:strategy) { distribution.strategy }

  shared_context 'mock backend call' do
    let(:staging_project) { create(:project, name: 'SUSE:SLE-12-SP2:Update:Products:CASP3:staging:A') }
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{staging_project}/_result?view=binarylist&package=CAASP-dvd5-DVD-x86_64&repository=images" }
    let(:backend_response) do
      %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
        <result project="#{staging_project}" repository='images' arch='x86_64' code='unpublished' state='unpublished'>
          <binarylist package='CAASP-dvd5-DVD-x86_64'>
            <binary filename='CASP-Build1039.1-Media.iso' size='879214592' mtime='1528427209'/>
            <binary filename='CASP-Build1039.1-Media.iso.sha256' size='623' mtime='1528427215'/>
            <binary filename='CASP-Build1039.1-Media.report' size='371629' mtime='1528427188'/>
            <binary filename='_channel' size='64345' mtime='1528427189'/>
            <binary filename='_statistics' size='716' mtime='1528427188'/>
          </binarylist>
        </result>
      </resultlist>)
    end
  end

  describe '#staging_manager' do
    it { expect(strategy.staging_manager).to eq('caasp-staging-managers') }
  end

  describe '#repo_url' do
    it { expect(strategy.repo_url).to be_nil }
  end

  describe 'openqa_version' do
    it { expect(strategy.openqa_version).to eq('3.0') }
  end

  describe 'openqa_iso' do
    include_context 'mock backend call'

    before do
      stub_request(:get, backend_url).and_return(body: backend_response)
    end

    it { expect(strategy.openqa_iso(staging_project)).to eq('CASP-Build1039.1-Media.iso') }
  end

  describe 'project_iso' do
    include_context 'mock backend call'

    before do
      stub_request(:get, backend_url).and_return(body: backend_response)
    end

    it { expect(strategy.project_iso(staging_project)).to eq('CASP-Build1039.1-Media.iso') }
  end
end
