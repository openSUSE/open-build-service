module Webui::InPlaceEditingHelper
  class InPlaceEditor
    attr_reader :object_name, :editable_id, :trigger_id, :trigger_classes, :form_id, :input_id, :update_url, :cancel_button_id, :refresh_target, :editable_object, :editable_field_name, :view_context

    def initialize(object, field_name, view_context, options)
      @editable_object = object
      @editable_field_name = field_name
      @view_context = view_context
      @object_name = object.class.model_name.to_s.underscore
      @editable_id = "#{object_name}-#{field_name}"
      @trigger_id = "#{@editable_id}-trigger" # The pencil-shaped control to trigger the edition
      @trigger_classes = 'fas fa-pen text-secondary small mb-1 ml-1'
      @form_id = "#{@editable_id}-form"
      @input_id = "#{@editable_id}-input"
      @update_url = [@object_name, "update".to_sym]
      @cancel_button_id = "#{@editable_id}-cancel"
      @refresh_target = options[:refresh_target_id]
    end

    def build_form_element_with_custom_component(&editing_control_builder)
      view_context.form_for(editable_object,
                            url: update_url,
                            remote: true,
                            method: :patch,
                            data: { type: 'html' },
                            html: { id: form_id, class: 'd-none' }) do |form|
        view_context.concat(view_context.hidden_field_tag(:id, editable_object.id))
        view_context.concat(editing_control_builder.call(form, editable_field_name, self))
        view_context.concat(form.submit("Save changes", class: 'btn btn-primary btn-sm ml-3'))
        view_context.concat(form.button("Cancel changes",
                                id: cancel_button_id,
                                class: 'btn btn-outline-danger btn-sm ml-3'));
      end
    end

    def build_auxiliar_markup!(form_element, &custom_element_builder)
      view_context.content_tag(:div, class: 'd-flex in-place-editing align-items-end', data: { id: editable_id, 'refresh-target-id': refresh_target }) do
        view_context.concat(view_context.content_tag(:div, class: 'triggering-wrapper') { custom_element_builder.call if block_given? })
        trigger_element = view_context.content_tag(:i, nil,
                                                   id: trigger_id,
                                                   class: trigger_classes)
        view_context.concat(trigger_element)
        view_context.concat(form_element)
      end
    end

    def build_form!
      raise NotImplementedError
    end

    def build!(&custom_element_builder)
      form = build_form!
      build_auxiliar_markup!(form, &custom_element_builder)
    end
  end

  class InPlaceTextAreaEditor < InPlaceEditor
    def build_form!
      build_form_element_with_custom_component do |form, field_name, editor|
        form.text_area(field_name.to_sym, id: editor.input_id)
      end
    end
  end

  class InPlaceTextFieldEditor < InPlaceEditor
    def build_form!
      build_form_element_with_custom_component do |form, field_name, editor|
        form.text_field(field_name.to_sym, id: editor.input_id)
      end
    end
  end

  def in_place_text_field(object, field_name, options = {}, &custom_element_builder)
    editor = InPlaceTextFieldEditor.new(object, field_name, self, options)
    editor.build!(&custom_element_builder)
  end

  def in_place_text_area(object, field_name, options = {}, &custom_element_builder)
    editor = InPlaceTextAreaEditor.new(object, field_name, self, options)
    editor.build!(&custom_element_builder)
  end
end
