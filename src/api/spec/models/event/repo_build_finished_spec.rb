require 'rails_helper'

RSpec.describe Event::RepoBuildFinished do
  describe 'UpdateNotificationEvents' do
    let(:path) { "#{CONFIG['source_url']}/lastnotifications?block=1&start=1" }
    let(:xml_response) do
      <<-HEREDOC
         <notifications next="2">
           <notification type="REPO_BUILD_FINISHED" time="1539445101">
            <data key="project">home:coolo</data>
            <data key="repo">standard</data>
            <data key="arch">x86_64</data>
            <data key="buildid">67394b7f7d6e15920e8f2096047c0b4a</data>
          </notification>
         </notifications>
      HEREDOC
    end

    before do
      create(:admin_user, login: 'Admin')
      stub_request(:get, path).and_return(body: xml_response)
      UpdateNotificationEvents.new.perform
    end

    it 'fetches from backend' do
      expect(Event::RepoBuildFinished.count).to be(1)
    end

    it 'gets the payload right' do
      expect(Event::RepoBuildFinished.first.payload).to include('buildid' => '67394b7f7d6e15920e8f2096047c0b4a',
                                                                'arch' => 'x86_64', 'project' => 'home:coolo', 'repo' => 'standard')
    end
  end
end
