require 'webmock/rspec'

RSpec.describe Webui::MonitorController do
  let(:xml_response) do
    <<-HEREDOC
    <workerstatus clients="7">
      <building workerid="simulated" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
      <building workerid="simulated" hostarch="i586" project="SourceprotectedProject" repository="repo" package="pack" arch="i586" starttime="0" />
      <building workerid="simulated" hostarch="x86_64" project="home:Iggy" repository="10.2" package="TestPack" arch="x86_64" starttime="0" />
      <building workerid="simulated" hostarch="i586" project="UseRemoteInstance" repository="pop" package="pack2.linked" arch="i586" starttime="0" />
      <building workerid="simulated" hostarch="i586" project="home:Iggy" repository="10.2" package="TestPack" arch="i586" starttime="0" />
      <building workerid="simulated" hostarch="i586" project="BaseDistro3" repository="BaseDistro3_repo" package="pack2" arch="i586" starttime="0" />
      <building workerid="simulated" hostarch="i586" project="HiddenProject" repository="nada" package="pack" arch="i586" starttime="0" />
      <waiting arch="i586" jobs="1" />
      <waiting arch="x86_64" jobs="0" />
      <blocked arch="i586" jobs="1" />
      <blocked arch="x86_64" jobs="0" />
      <buildavg arch="i586" buildavg="1200" />
      <buildavg arch="x86_64" buildavg="1200" />
      <partition>
        <daemon type="scheduler" arch="i586" state="dead">
          <queue high="0" med="0" low="3" next="0" />
        </daemon>
        <daemon type="scheduler" arch="x86_64" state="dead">
          <queue high="0" med="0" low="6" next="0" />
        </daemon>
        <daemon type="publisher" state="dead" />
      </partition>
    </workerstatus>
    HEREDOC
  end

  describe 'GET #index' do
    before do
      stub_request(:get, "#{CONFIG['source_url']}/build/_workerstatus").and_return(body: xml_response)
      get :index
    end

    it { is_expected.to render_template('webui/monitor/index') }
  end

  describe 'GET #old' do
    before do
      stub_request(:get, "#{CONFIG['source_url']}/build/_workerstatus").and_return(body: xml_response)
      get :old
    end

    it { is_expected.to render_template('webui/monitor/old') }
  end

  describe 'GET #update_building' do
    let(:json_response) { response.parsed_body }

    before do
      stub_request(:get, "#{CONFIG['source_url']}/build/_workerstatus").and_return(body: xml_response)
      get :update_building, xhr: true
    end

    it { expect(json_response).to have_key('simulated') }
  end

  describe 'GET #events' do
    let(:json_response) { response.parsed_body }

    before do
      # x86_64
      create_list(:status_history,  2, source: 'squeue_high')
      create_list(:status_history,  5, source: 'squeue_med', range: 0..400)
      create_list(:status_history,  9, source: 'building', range: 10..42)
      create_list(:status_history, 10, source: 'waiting', range: 10_000..42_000)
      # i586
      create_list(:status_history, 5, source: 'squeue_high', architecture: 'i586')
      # the factory creates the events 0..8000 hours ago
      get :events, params: { arch: 'x86_64', range: 8100 }, xhr: true
    end

    it { expect(json_response['events_max']).to be <= 800 }
    it { expect(json_response['jobs_max']).to be <= 84_000 }
    it { expect(json_response['squeue_high'].length).to eq(2) }
    it { expect(json_response['squeue_med'].length).to eq(5) }
    it { expect(json_response['building'].length).to eq(9) }
    it { expect(json_response['waiting'].length).to eq(10) }
  end
end
