RSpec.describe ModalComponent, type: :component do
  describe '#modal_object' do
    context 'creating a modal header, footer and button slots content' do
      before do
        component = described_class.new(modal_id: 'simple', modal_button_data: { text: 'Open modal dialog' })
        component.with_header { 'Simple modal header' }
        component.with_footer { 'Footer modal dialog' }

        render_inline(component)
      end

      it 'renders the content for the header slot' do
        expect(rendered_content).to have_text('Simple modal header', count: 1)
      end

      it 'renders the content for the footer slot' do
        expect(rendered_content).to have_text('Footer modal dialog', count: 1)
      end

      it 'renders the content for the button slot' do
        expect(rendered_content).to have_text('Open modal dialog', count: 1)
      end
    end
  end
end
