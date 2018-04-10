# frozen_string_literal: true
require 'rails_helper'
# WARNING: If you change #file_exists or #has_file test make sure
# you uncomment the next line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe UpdateReleasedBinariesJob, vcr: true do
  describe '#perform' do
    let!(:project) { create(:project, name: 'apache') }
    let!(:repository) { create(:repository, name: 'mod_ssl', project: project, architectures: ['i586']) }
    let!(:event) { Event::Packtrack.create(project: project.name, repo: repository.name, payload: 'fake_payload') }

    context 'for an event with a repo' do
      before do
        allow(BinaryRelease).to receive(:update_binary_releases)
      end

      subject! { UpdateReleasedBinariesJob.perform_now(event.id) }

      it { expect(BinaryRelease).to have_received(:update_binary_releases) }
    end

    context 'for an event without a repo' do
      let!(:event_without_repo) do
        Event::Packtrack.create(project: project.name, repo: nil, payload: 'fake_payload')
      end

      before do
        allow(BinaryRelease).to receive(:update_binary_releases)
      end

      subject! { UpdateReleasedBinariesJob.perform_now(event_without_repo.id) }

      it { expect(BinaryRelease).not_to have_received(:update_binary_releases) }
    end

    context 'when perform raises an exception' do
      before do
        allow(BinaryRelease).to receive(:update_binary_releases).and_raise(StandardError)
        allow($stdout).to receive(:write) # Needed to avoid the puts of the error method
      end

      before do
        allow(Airbrake).to receive(:notify)
      end

      subject! { UpdateReleasedBinariesJob.perform_now(event.id) }

      it 'notifies airbrake' do
        expect(Airbrake).to have_received(:notify)
      end
    end
  end
end
