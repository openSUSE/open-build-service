class CardComponentPreview < ViewComponent::Preview
  def with_header
    render(CardComponent.new) do |component|
      component.with_header do
        tag.a('openSUSE_Factory', href: '#').concat(
          tag.span('tag-1', class: 'badge bg-primary ms-1')
        ).concat(
          tag.span('tag-2', class: 'badge bg-primary ms-1')
        ).concat(
          tag.span('tag-3', class: 'badge bg-primary ms-1')
        ).concat(
          tag.span('tag-4', class: 'badge bg-primary ms-1')
        )
      end
      tag.strong('Repository paths:').concat(
        content_tag(
          :ol,
          content_tag(
            :li,
            tag.span('SUSE:SLE-15-SP4:GA/standard').concat(
              content_tag(
                :a,
                tag.i(class: 'fas fa-sm fa-times-circle text-danger'),
                href: '#',
                title: 'Delete',
                class: 'ms-2'
              )
            )
          ),
          class: 'list-unstyled ms-3'
        )
      )
    end
  end

  def with_delete_button
    render(CardComponent.new) do |component|
      component.with_delete_button do
        content_tag(
          :a,
          tag.i(class: 'fas fa-sm fa-times-circle text-danger'),
          href: '#',
          title: 'Delete'
        )
      end
      content_tag(
        :div,
        tag.input(
          type: 'checkbox',
          name: '',
          id: 'input-id',
          value: 'true',
          class: 'form-check-input group-maintainership'
        ).concat(
          tag.label(
            'Maintainer',
            class: 'form-check-label',
            for: 'input-id'
          )
        ),
        class: 'form-check mt-2'
      )
    end
  end

  def with_actions
    render(CardComponent.new) do |component|
      component.with_header do
        content_tag(:a, tag.h5('Run our OBS Workflow', class: 'card-title font-italic'), href: '#')
      end
      component.with_action do
        content_tag(:a, tag.i(class: 'fas fa-edit'), href: '#', title: 'Edit Token', class: 'nav-link p-1')
      end
      component.with_action do
        content_tag(:a, tag.i(class: 'fas fa-project-diagram'), href: '#', title: 'Trigger Token', class: 'nav-link p-1')
      end
      tag.p('Id: 4763', class: 'card-text').concat(
        tag.p('Operation: Rebuild', class: 'card-text')
      ).concat(
        content_tag(
          :p,
          tag.span('Runs as: ').concat(tag.a('user', href: '#')),
          class: 'card-text'
        )
      )
    end
  end
end
