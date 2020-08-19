require 'rails_helper'

RSpec.describe ::MonitorControllerService::BuildingInformationUpdater do
  let(:bi_information) { ::MonitorControllerService::BuildingInformationUpdater.new }
  let(:xml_response) do
    <<-HEREDOC
            <workerstatus clients="7">
            <idle workerid="build01/1" hostarch="x86_64"/>
            <building workerid="build01/2" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
            <building workerid="build01/3" hostarch="i586" project="SourceprotectedProject" repository="repo" package="pack" arch="i586" starttime="#{(Time.now - 30.minutes).to_i}" />
            <building workerid="build01/4" hostarch="i586" project="HiddenProject" repository="nada" package="pack" arch="i586" starttime="#{(Time.now - 1.hour).to_i}" />
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

  before do
    # rubocop:disable RSpec/MessageChain
    allow(WorkerStatus).to receive_message_chain('hidden.to_xml').and_return(xml_response)
    # rubocop:enable RSpec/MessageChain
  end

  describe '#call' do
    subject { bi_information.call }

    it { expect(subject).not_to be_nil }
  end

  describe '#workers' do
    subject { bi_information.call.workers }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to have_key('build01_1') }
    it { expect(subject['build01_1']).to be_empty }
    it { expect(subject).to have_key('build01_2') }
    it { expect(subject['build01_2']).to have_key('delta') }
    it { expect(subject['build01_2']['delta']).to eq('100') }
    it { expect(subject['build01_3']).to have_key('delta') }
    it { expect(subject['build01_3']['delta']).to eq('48') }
    it { expect(subject['build01_4']).to have_key('delta') }
    it { expect(subject['build01_4']['delta']).to eq('66') }
  end
end
