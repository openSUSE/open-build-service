RSpec.describe ButtonComponent, type: :component do
  describe '#button_object' do
    context 'creating a button with text' do
      before do
        render_inline(described_class.new(type: 'info', text: 'Button text'))
      end

      it 'renders the button with the text' do
        expect(rendered_content).to have_text('Button text', count: 1)
      end
    end

    context 'creating a success button' do
      before do
        render_inline(described_class.new(type: 'success'))
      end

      it 'renders the success button' do
        expect(rendered_content).to have_css('.btn-success', count: 1)
      end
    end
  end
end
