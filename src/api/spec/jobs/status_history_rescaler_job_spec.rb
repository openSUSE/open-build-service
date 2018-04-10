# frozen_string_literal: true
require 'rails_helper'

RSpec.describe StatusHistoryRescalerJob, type: :job do
  include ActiveJob::TestHelper

  describe '#rescale' do
    before do
      Timecop.freeze(2010, 7, 12)

      now = Time.now.to_i - 2.days
      StatusHistory.transaction do
        1000.times do |i|
          StatusHistory.create time: now + i, key: 'idle_x86_64', value: i
        end
      end

      StatusHistory.create time: Time.now.to_i, key: 'busy_x86_64', value: 100
    end

    after do
      Timecop.return
    end

    subject! { StatusHistoryRescalerJob.new.perform }

    it { expect(StatusHistory.count).to eq(2) }

    it 'keeps the StatusHistory with key = idle_x86_64' do
      status_histories = StatusHistory.where(key: 'idle_x86_64')
      expect(status_histories.count).to eq(1)
      expect(status_histories.first.value).to eq(499.5)
    end
  end
end
