module Webui::InPlaceEditingHelper
  class InPlaceEditor
    attr_reader :object_name, :editable_id, :trigger_id, :trigger_classes, :form_id, :input_id, :update_url, :cancel_button_id, :refresh_target

    def initialize(object, field_name, options)
      @object_name = object.class.model_name.to_s.underscore
      @editable_id = "#{object_name}-#{field_name}"
      @trigger_id = "#{@editable_id}-trigger" # The pencil-shaped control to trigger the edition
      @trigger_classes = 'fas fa-pen text-secondary small mb-3 ml-1'
      @form_id = "#{@editable_id}-form"
      @input_id = "#{@editable_id}-input"
      @update_url = [@object_name, "update".to_sym]
      @cancel_button_id = "#{@editable_id}-cancel"
      @refresh_target = options[:refresh_target_id]
    end
  end

  def build_form_element(object, field_name, editor, &custom_element_builder)
    form_for(object,
             url: editor.update_url,
             remote: true,
             method: :patch,
             data: { type: 'html' },
             html: { id: editor.form_id, class: 'd-none' }) do |form|
      concat(hidden_field_tag(:id, object.id))
      concat(custom_element_builder.call(form, field_name, editor))
      concat(form.submit("Save changes"))
      concat(form.button("Cancel changes", id: editor.cancel_button_id));
    end
  end

  def in_place_text_field(object, field_name, options = {}, &block)
    editor = InPlaceEditor.new(object, field_name, options)
    form_element = build_form_element(object, field_name, editor) do |form, field_name, editor|
      form.text_field(field_name.to_sym, id: editor.input_id)
    end

    content_tag(:div, class: 'd-flex in-place-editing align-items-end', data: { id: editor.editable_id, 'refresh-target-id': editor.refresh_target }) do
      concat(content_tag(:div, class: 'triggering-wrapper') { block.call if block_given? })
      trigger_element = content_tag(:i, nil,
                                    id: editor.trigger_id,
                                    class: editor.trigger_classes)
      concat(trigger_element)
      concat(form_element)
    end
  end

  def in_place_text_area(object, field_name, options = {}, &block)
    editor = InPlaceEditor.new(object, field_name, options)
    form_element = build_form_element(object, field_name, editor) do |form, field_name, editor|
      form.text_area(field_name.to_sym, id: editor.input_id)
    end

    content_tag(:div, class: 'd-flex in-place-editing align-items-end', data: { id: editor.editable_id, 'refresh-target-id': editor.refresh_target }) do
      concat(content_tag(:div, class: 'triggering-wrapper') { block.call if block_given? })
      trigger_element = content_tag(:i, nil,
                                    id: editor.trigger_id,
                                    class: editor.trigger_classes)
      concat(trigger_element)
      concat(form_element)
    end
  end
end
