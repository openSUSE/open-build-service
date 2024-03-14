RSpec.describe ConfigurationWriteToBackendJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:configuration) { create(:configuration) }

    before do
      allow(Configuration).to receive(:find).and_return(configuration)
      allow(configuration).to receive(:write_to_backend)

      ConfigurationWriteToBackendJob.new.perform(configuration.id)
    end

    it 'writes to the backend' do
      expect(configuration).to have_received(:write_to_backend)
    end
  end
end
