RSpec.describe StatusHistoryRescalerJob do
  include ActiveJob::TestHelper

  let(:status_histories) { StatusHistory.where(key: 'busy_x86_64').order(:time) }

  describe '#rescale' do
    context 'newer than 2 hours records' do
      before do
        5.times { |i| StatusHistory.create(time: (Time.now.utc - i.seconds).to_i, key: 'busy_x86_64', value: i * 10) }

        StatusHistoryRescalerJob.perform_now
      end

      it 'keeps the StatusHistory with key = busy_x86_64' do
        expect(status_histories.count).to eq(5)
        expect(status_histories.first.value).to eq(40)
        expect(status_histories.last.value).to eq(0.0)
      end
    end

    context 'newer than 9 days' do
      before do
        2.times { |i| StatusHistory.create(time: 9.days.ago + i.minutes, key: 'busy_x86_64', value: i * 10) }
        2.times { |i| StatusHistory.create(time: 3.hours.ago + i.minutes, key: 'busy_x86_64', value: i * 10) }

        StatusHistoryRescalerJob.perform_now
      end

      it 'reduces the records older than 7 days to 1' do
        expect(StatusHistory.count).to eq(3)
      end

      it { expect(status_histories.first.value).to eq(5.0) }
    end

    context 'older than one month' do
      before do
        2.times { |i| StatusHistory.create(time: 9.months.ago + i.minutes, key: 'busy_x86_64', value: i * 10) }
        2.times { |i| StatusHistory.create(time: 3.months.ago + i.minutes, key: 'busy_x86_64', value: i * 10) }
        2.times { |i| StatusHistory.create(time: 3.hours.ago + i.minutes, key: 'busy_x86_64', value: i * 10) }

        StatusHistoryRescalerJob.perform_now
      end

      it 'reduces the records older than 1 month to 1' do
        expect(StatusHistory.count).to eq(4)
      end

      it { expect(Time.at(status_histories.first.time).utc).to be_between(10.months.ago, 8.months.ago) }
      it { expect(status_histories.first.value).to eq(5.0) }
      it { expect(status_histories.last.value).to eq(10.0) }
    end
  end
end
