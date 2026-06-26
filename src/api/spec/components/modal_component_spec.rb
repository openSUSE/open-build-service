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

    context 'when testing the preview' do
      it 'renders the modal with button' do
        render_preview(:simple_modal_with_button)

        expect(rendered_content).to have_text('Simple modal header')
      end

      it 'renders the modal with icon and button' do
        render_preview(:simple_modal_with_icon_button)

        expect(rendered_content).to have_text('Simple modal header')
      end

      it 'renders the modal with text button' do
        render_preview(:simple_modal_with_text_button)

        expect(rendered_content).to have_text('Simple modal header')
      end
    end
  end
end
