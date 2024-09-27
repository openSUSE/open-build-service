RSpec.describe Webui::ColorHelper do
  describe '#contrast_text' do
    context 'when passing a light color' do
      it 'returns a black text' do
        expect(contrast_text('#ffffff')).to eql('black')
      end
    end

    context 'when passing a dark color' do
      it 'returns a white text' do
        expect(contrast_text('#000000')).to eql('white')
      end
    end
  end
end
