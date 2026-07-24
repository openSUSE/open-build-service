require 'browser_helper'
require 'webmock/rspec'

RSpec.describe 'Monitor', :js, :vcr do
  let(:xml_response) do
    <<~XML
      <workerstatus clients="2">
        <building workerid="build01/3" hostarch="i586" project="home:Iggy" repository="10.2" package="TestPack" arch="i586" starttime="#{30.minutes.ago.to_i}" />
        <building workerid="build01/4" hostarch="i586" project="HiddenProject" repository="nada" package="pack" arch="i586" starttime="#{1.hour.ago.to_i}" />
      </workerstatus>
    XML
  end

  before do
    create(:project, name: 'home:Iggy')
    stub_request(:get, "#{CONFIG['source_url']}/build/_workerstatus").and_return(body: xml_response)
  end

  it 'does not link hidden workers to broken build logs' do
    visit monitor_path

    visible_worker = find('#pbuild01_3 .monitorpb_text', text: 'TestPack')
    expect(visible_worker[:href]).to match(%r{/package/live_build_log/home(?::|%3A)Iggy/TestPack/10\.2/i586\z})

    hidden_worker = find('#pbuild01_4 .monitorpb_text', text: '---')
    expect(hidden_worker[:href]).to be_nil
  end
end
