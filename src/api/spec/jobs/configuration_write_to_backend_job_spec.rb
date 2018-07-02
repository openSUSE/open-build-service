require 'rails_helper'

RSpec.describe ConfigurationWriteToBackendJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:configuration) { create(:configuration) }

    before do
      allow(Configuration).to receive(:find).and_return(configuration)
      allow(configuration).to receive(:write_to_backend)
    end

    subject! { ConfigurationWriteToBackendJob.new.perform(configuration.id) }

    it 'writes to the backend' do
      expect(configuration).to have_received(:write_to_backend)
    end
  end
end
