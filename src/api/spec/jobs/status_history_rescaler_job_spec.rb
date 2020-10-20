require 'rails_helper'

RSpec.describe StatusHistoryRescalerJob, type: :job do
  include ActiveJob::TestHelper

  describe '#rescale' do
    let(:now) { Time.now.to_i - 2.days }
    let(:idle_status_histories) { StatusHistory.where(key: 'idle_x86_64') }
    let(:busy_status_histories) { StatusHistory.where(key: 'busy_x86_64') }

    before do
      StatusHistory.transaction do
        10.times { |i| StatusHistory.create(time: now + i, key: 'idle_x86_64', value: i) }
        2.times { |i| StatusHistory.create(time: now + i, key: 'busy_x86_64', value: i) }
      end
    end

    subject! { StatusHistoryRescalerJob.perform_now }

    context 'StatusHistory Total' do
      it { expect(StatusHistory.count).to eq(2) }
    end

    context 'Status histories for idle_x86_64' do
      it { expect(idle_status_histories.count).to eq(1) }
      it { expect(idle_status_histories.first.value).to eq(4.5) }
    end

    context 'Status histories for busy_x86_64' do
      it { expect(busy_status_histories.count).to eq(1) }
      it { expect(busy_status_histories.first.value).to eq(0.5) }
    end
  end
end
