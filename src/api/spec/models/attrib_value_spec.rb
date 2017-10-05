require 'rails_helper'

RSpec.describe AttribValue, type: :model do
  describe '#to_s' do
    let(:attrib) { create(:attrib_with_default_value) }

    context 'without setting a value' do
      let(:attrib_value) { create(:attrib_value, attrib: attrib) }
      let(:default_value) { attrib.attrib_type.default_values.first.value }

      before do
        attrib_value.reload
      end

      it 'uses the default value' do
        expect(attrib_value.to_s).to eq(default_value)
      end
    end

    context 'with a value' do
      let(:attrib_value) { create(:attrib_value, attrib: attrib, value: 'value that is set') }

      it 'returns the value which is set' do
        expect(attrib_value.to_s).to eq('value that is set')
      end
    end
  end
end
