require 'rails_helper'

RSpec.describe UpdateReleasedBinaries, vcr: true do
  let(:project) { create(:project_with_repository) }
  let(:repository) { project.repositories.first }
  let(:event) { Event::Packtrack.new('project' => project.name, 'repo' => repository.name, 'payload' => 'fake_payload') }
  let(:event_without_repo) { Event::Packtrack.new('project' => project.name, 'repo' => nil, 'payload' => 'fake_payload') }

  context "properly set" do
    subject { UpdateReleasedBinaries.new(event) }

    after do
      Delayed::Job.enqueue subject
    end

    it { expect(BinaryRelease).to receive(:update_binary_releases).twice }
    it { expect(subject).to receive(:after) }
    it { expect(subject).not_to receive(:error) }
  end

  context "without a repo properly set" do
    subject { UpdateReleasedBinaries.new(event_without_repo) }

    after do
      Delayed::Job.enqueue subject
    end

    it { expect(subject.perform).to be_nil }
    it { expect(BinaryRelease).not_to receive(:update_binary_releases) }
  end

  context "when perform raises an exception" do
    before do
      allow(BinaryRelease).to receive(:update_binary_releases).and_raise('FakeExceptionMessage')
    end

    subject { UpdateReleasedBinaries.new(event) }

    it 'runs #error' do
      is_expected.to receive(:error)
      expect { Delayed::Job.enqueue subject }.to raise_error('FakeExceptionMessage')
    end
  end
end
