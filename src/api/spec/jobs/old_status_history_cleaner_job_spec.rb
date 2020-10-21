require 'rails_helper'

RSpec.describe OldStatusHistoryCleanerJob, type: :job do
  include ActiveJob::TestHelper

  describe '.perform' do
    let(:last_year) { 15.months.ago }
    let(:now) { Time.now.to_i }

    before do
      StatusHistory.transaction do
        10.times do |i|
          StatusHistory.create(time: last_year + i, key: 'idle_x86_64', value: i)
          StatusHistory.create(time: now + i, key: 'idle_x86_64', value: i)
        end
      end
    end

    it { expect { described_class.perform_now }.not_to raise_error }
    it { expect(described_class.perform_now).to eq(10) }
  end
end
