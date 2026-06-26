class ModalComponentPreview < ViewComponent::Preview
  def simple_modal_with_button
    render(ModalComponent.new(modal_id: 'simple',
                              modal_button_data: { text: 'Open modal dialog',
                                                   type: 'info',
                                                   icon: 'fa fa-eye' })) do |component|
      component.with_header { tag.span('Simple modal header') }
      component.with_footer do
        tag.button('Cancel',
                   class: 'btn btn-outline-danger',
                   data: { 'bs-dismiss': 'modal' })
           .concat(tag.button('Simple button', class: 'btn btn-success'))
      end
      tag.span('Simple modal content')
    end
  end

  def simple_modal_with_icon_button
    render(ModalComponent.new(modal_id: 'simple',
                              modal_button_data: { type: 'warning',
                                                   icon: 'fa fa-eye' })) do |component|
      component.with_header { tag.span('Simple modal header') }
      component.with_footer { tag.button('Simple button', class: 'btn btn-warning') }
      tag.span('Simple modal content')
    end
  end

  def simple_modal_with_text_button
    render(ModalComponent.new(modal_id: 'simple',
                              modal_button_data: { type: 'info',
                                                   text: 'Open modal dialog' })) do |component|
      component.with_header { tag.span('Simple modal header') }
      component.with_footer { tag.button('Simple button', class: 'btn btn-success') }
      tag.span('Simple modal content')
    end
  end
end
