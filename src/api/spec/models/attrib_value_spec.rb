require 'rails_helper'

RSpec.describe AttribValue, type: :model do
  describe '#to_s' do
    let(:attrib_value) { create(:attrib_value, default_value: 'this is my default value') }

    context 'without setting a value' do
      it 'uses the default value' do
        expect(attrib_value.to_s).to eq('this is my default value')
      end
    end

    context 'with a value' do
      let(:attrib_value) { create(:attrib_value, value: 'value that is set') }

      it 'returns the value which is set' do
        expect(attrib_value.to_s).to eq('value that is set')
      end
    end
  end
end
