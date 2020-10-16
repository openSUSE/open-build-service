require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Service, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:service) { package.services }
  let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package.name}" }

  describe '.verify_xml!' do
    let(:valid_xml) do
      <<~XML
        <services>
          <service name="verify_file">
            <param name="file">krabber-1.0.tar.gz</param>
            <param name="verifier">sha256</param>
            <param name="checksum">7f535a96a834b31ba2201</param>
          </service>
        </services>
      XML
    end
    let(:long_name) { 'X' * 300 }
    let(:invalid_xml) do
      <<~XML
        <services>
          <service name="#{long_name}" mode="disabled" />
        </services>
      XML
    end

    it { expect { Service.verify_xml!(valid_xml) }.not_to raise_error }
    it { expect { Service.verify_xml!(invalid_xml) }.to raise_error(Service::InvalidParameter) }
  end

  describe '#add_download_url' do
    it { expect(service.add_download_url('http://example.org/foo.git')).to be_truthy }
    it { expect(service.add_download_url('<>')).to be_falsey }
  end

  describe '#add_service' do
    let(:git_service) { service.add_service('obs_scm', [{ name: 'scm', value: 'git' }, { name: 'url', value: url }]) }

    it { expect(git_service).to be_a(Nokogiri::XML::Element) }
    it { expect(git_service.xpath('//param').size).to eq(2) }
    it { expect(git_service.xpath('//param').first.text).to eq('git') }
  end

  describe '#add_kiwi_import' do
    before do
      login(user)
      service.add_kiwi_import
    end

    it 'posts runservice' do
      expect(a_request(:post, "#{url}?cmd=runservice&user=#{user}")).to have_been_made.once
    end

    it 'posts mergeservice' do
      skip('broken because KiwiImport service expects a tar archive, we should move this in Package#save_file.')
      expect(a_request(:post, "#{url}?cmd=mergeservice&user=#{user}")).to have_been_made.once
    end

    it 'posts waitservice' do
      expect(a_request(:post, "#{url}?cmd=waitservice")).to have_been_made.once
    end

    it 'has a kiwi_import service' do
      expect(service.document.xpath("/services/service[@name='kiwi_import']")).not_to be_empty
    end
  end
end
