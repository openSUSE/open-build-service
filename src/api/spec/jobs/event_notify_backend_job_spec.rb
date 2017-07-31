require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe EventNotifyBackendJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:project) { create(:project) }
    let(:response) { double(:response, body: '<response code="ok"/>') }

    before do
      Event::CreateProject.create(project: project.name)
      allow(Backend::Connection).to receive(:post).and_return(response)
    end

    subject! { EventNotifyBackendJob.new.perform }

    it 'posts to the backend' do
      expect(Backend::Connection).to have_received(:post)
    end
  end
end
