require 'rails_helper'

RSpec.describe WorkerStatusService::JobsStatisticsFetcher do
  subject { described_class.call }

  let(:xml_response) do
    <<-HEREDOC
          <workerstatus clients="1">
          <building workerid="build01/2" hostarch="i586" project="foo" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <waiting arch="i586" jobs="1" />
          <blocked arch="i586" jobs="1" />
          <buildavg arch="i586" buildavg="1200" />
          <partition>
            <daemon type="scheduler" arch="i586" state="dead">
            <queue high="0" med="0" low="3" next="0" />
            </daemon>
            <daemon type="publisher" state="dead" />
          </partition>
          </workerstatus>
    HEREDOC
  end

  before do
    allow(Backend::Api::BuildResults::Worker).to receive(:status).and_return(xml_response)
  end

  it { expect(subject).to include(:blocked, :waiting) }
  it { expect(subject[:blocked]).to be_a(Hash) }
  it { expect(subject[:waiting]).to be_a(Hash) }
end
