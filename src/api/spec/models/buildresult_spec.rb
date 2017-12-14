require 'rails_helper'
require 'webmock/rspec'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe Buildresult, vcr: true do
  describe '#status_description' do
    it 'returns a message when a status code is unknown' do
      expect(Buildresult.status_description('unknown_status')).to eq('status explanation not found')
    end

    it 'returns an explanation for a status' do
      expect(Buildresult.status_description('succeeded')).not_to eq('status explanation not found')
    end
  end

  describe '#summary' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:home_project) { user.home_project }
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{home_project}/_result?view=summary" }

    let(:local_build_result) { subject['openSUSE'].first }
    let(:result) { { architecture: 'i586', code: 'published', repository: 'openSUSE', state: 'published' } }
    let(:status_count) { local_build_result.summary.first }

    subject { Buildresult.summary(home_project) }

    before do
      stub_request(:get, backend_url).and_return(body:
      %(<resultlist state="dea55075a09a8497bad40a28c01cfdad">
          <result project="#{home_project}" repository="openSUSE" arch="i586" code="published" state="published">
            <summary>
              <statuscount code="succeeded" count="5"/>
            </summary>
          </result>
        </resultlist>))
    end

    it { expect(subject).to have_key('openSUSE') }
    it { expect(local_build_result).to have_attributes(result) }
    it { expect(status_count).to have_attributes(code: 'succeeded', count: '5') }
  end
end
