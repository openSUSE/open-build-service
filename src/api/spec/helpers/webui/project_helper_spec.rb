require 'rails_helper'

RSpec.describe Webui::ProjectHelper, type: :helper do
  describe '#format_seconds' do
    it 'shows a zero for the hour if under 3600 seconds' do
      expect(format_seconds(60)).to eq('0:01')
    end

    it 'shows hours and seconds properly' do
      expect(format_seconds(12_000)).to eq('3:20')
    end
  end

  describe '#rebuild_time_col' do
    skip
  end
end
