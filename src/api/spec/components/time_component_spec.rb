require 'rails_helper'

RSpec.describe TimeComponent, type: :component do
  context 'time is in the past' do
    let(:time) { 2.days.ago }

    it { expect(render_inline(described_class.new(time: time))).to have_text('ago') }
  end

  context 'time in the last minute is in the past' do
    let(:time) { 1.second.ago }

    it { expect(render_inline(described_class.new(time: time))).to have_text('less than a minute ago') }
  end

  context 'time in the next minute is in the future' do
    let(:time) { 10.seconds.since }

    it { expect(render_inline(described_class.new(time: time))).to have_text('in less than a minute') }
  end

  context 'time is in the future' do
    let(:time) { 1.day.since }

    it { expect(render_inline(described_class.new(time: time))).to have_text('in') }
  end
end
