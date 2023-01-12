require 'rails_helper'

RSpec.describe PackageService::SchemaVerifier do
  let!(:package) { create(:package, name: 'chromium') }
  let(:schema_verifier) { described_class.new(file_name: file_name, package: package, content: content) }

  describe '.call' do
    subject { schema_verifier.call }

    context 'no error' do
      let(:file_name) { 'foo' }
      let(:content) { 'bar' }

      it { expect { subject }.not_to raise_error }
    end

    context 'right pattern' do
      let!(:package) { create(:package, name: '_pattern') }
      let(:file_name) { 'OBS-Server' }
      let(:content) do
        <<-XML_DATA
            <pattern xmlns="http://novell.com/package/metadata/suse/pattern"
                     xmlns:rpm="http://linux.duke.edu/metadata/rpm">
                <name>OBS_Server</name>
                <summary lang="en">Open Build Service Server</summary>
                <description lang="en">The Open Build Service is an enviroment to allow
                    automated package building. The official server from the openSUSE project
                    is reachable at http://build.opensuse.org .
                </description>
                <uservisible/>
                <category lang="en">System</category>
                <rpm:requires>
                    <rpm:entry name="obs-server"/>
                </rpm:requires>
            </pattern>
        XML_DATA
      end

      it { expect { subject }.not_to raise_error }
    end

    context 'wrong pattern' do
      let!(:package) { create(:package, name: '_pattern') }
      let(:file_name) { 'OBS-Server' }
      let(:content) { 'foo' }

      it { expect { subject }.to raise_error(Suse::ValidationError) }
    end
  end
end
