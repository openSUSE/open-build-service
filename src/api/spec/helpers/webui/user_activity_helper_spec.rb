require 'rails_helper'

RSpec.describe Webui::UserActivityHelper do
  describe '#contributions_percentiles' do
    subject { contributions_percentiles(contributions_array) }

    context 'very few contributions' do
      let(:contributions_array) { [1] }

      it 'returns all the same' do
        expect(subject).to eq([1, 1, 1])
      end
    end

    context 'sparse contributions' do
      let(:contributions_array) { [1, 1, 1, 2, 2, 3, 5] }

      it 'returns high numbers as percentiles' do
        expect(subject).to eq([2, 3, 5])
      end
    end
  end
end
