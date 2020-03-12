module Webui::InPlaceEditingHelper
  def render_controls
    content_tag(:div, class: 'basic-info mb-3 d-flex justify-content-end', id: 'project-in-place-editing') do
      concat(link_to('Edit', '#', id: 'in-place-editing-edit-button', class: 'btn btn-primary btn-sm'))
      concat(link_to('Cancel', '#', id: 'in-place-editing-cancel-button', class: 'btn btn-outline-danger btn-sm d-none'))
    end
  end

  def render_editing_form(object)
    object_type = object.class.to_s.underscore.to_sym
    content_tag(:div, class: 'in-place-editing-form-wrapper d-none') do
      form_for(object,
               url: url_for(controller: object_type, action: 'update'),
               method: :patch, remote: true, html: { id: 'in-place-editing-form' }) do |form|
        content_tag(:h5, 'Edit Project')
        render(partial: 'edit', locals: { form: form, project: object })
      end
    end
  end

  def render_read_only_content(object)
    content_tag(:div, class: 'in-place-editing-content') do
      concat(render(partial: 'basic_info', locals: { project: object }))
    end
  end

  def in_place_editing(object)
    concat(render_controls)
    concat(render_editing_form(object))
    concat(render_read_only_content(object))
    content_for(:ready_function, 'activate_in_place_editing();')
  end
end
