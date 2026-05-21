class InputComponentPreview < ViewComponent::Preview
  def with_label
    render(InputComponent.new) do |component|
      component.with_label do
        content_tag(
          :label,
          'Search:',
          for: 'search_text'
        )
      end
      tag.input(type: 'text',
                name: 'search_text',
                id: 'search_text',
                class: 'form-control',
                placeholder: 'Search',
                value: '',
                'aria-label': 'Search text')
    end
  end

  def with_label_and_icon
    render(InputComponent.new) do |component|
      component.with_label do
        content_tag(
          :label,
          'Search:',
          for: 'search_text'
        )
      end
      component.with_icon do
        tag.i(class: 'fas fa-search')
      end
      tag.input(type: 'text',
                name: 'search_text',
                id: 'search_text',
                class: 'form-control',
                placeholder: 'Search',
                value: '',
                'aria-label': 'Search text')
    end
  end

  def with_label_and_button
    render(InputComponent.new) do |component|
      component.with_label do
        content_tag(
          :label,
          'Search:',
          for: 'search_text'
        )
      end
      component.with_button do
        tag.button('Submit', class: 'btn btn-outline-secondary')
      end
      tag.input(type: 'text',
                name: 'search_text',
                id: 'search_text',
                class: 'form-control',
                placeholder: 'Search',
                value: '',
                'aria-label': 'Search')
    end
  end
end
