require 'rails_helper'

RSpec.describe FuzzyTimeComponent, type: :component do
  context 'time is in the past' do
    let(:time) { 2.days.ago }

    it { expect(render_inline(described_class.new(time: time))).to have_text('ago') }
  end

  context 'time is in the present' do
    let(:time) { 1.second.ago }

    it { expect(render_inline(described_class.new(time: time))).to have_text('now') }
  end
end
