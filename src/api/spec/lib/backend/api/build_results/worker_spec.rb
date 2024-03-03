RSpec.describe Backend::Api::BuildResults::Worker do
  before do
    allow(described_class).to receive(:http_get).and_return(nil)
  end

  describe '.status' do
    it 'calls http_get with the correct endpoint' do
      described_class.status
      expect(described_class).to have_received(:http_get).with('/build/_workerstatus')
    end
  end

  describe '.capabilities' do
    it 'calls http_get with the correct endpoint and parameters' do
      arch = 'x86_64'
      worker_id = 'worker123'

      described_class.capabilities(arch, worker_id)
      expect(described_class).to have_received(:http_get).with("/worker/#{arch}:#{worker_id}")
    end
  end
end
