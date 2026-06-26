class ButtonComponentPreview < ViewComponent::Preview
  def with_text_and_icon
    render(ButtonComponent.new(type: 'success', text: 'Simple button', icon_type: 'eye'))
  end

  def small_with_icon
    render(ButtonComponent.new(type: 'info', icon_type: 'plus', css_custom: 'btn-sm'))
  end

  def info_button
    render(ButtonComponent.new(type: 'info', icon_type: 'info', text: 'Info button'))
  end

  def success_button
    render(ButtonComponent.new(type: 'success', icon_type: 'check', text: 'Success button'))
  end

  def warning_small_button
    render(ButtonComponent.new(type: 'warning', css_custom: 'btn-sm', text: 'Warning button', icon_type: 'warning'))
  end

  def danger_button
    render(ButtonComponent.new(type: 'danger', icon_type: 'fire', text: 'Danger button'))
  end

  def info_outline_custom_icon_button
    render(ButtonComponent.new(type: 'outline-info', text: 'Info outline button', icon_type: 'info'))
  end

  def no_type_button
    render(ButtonComponent.new(icon_type: 'question', text: 'Unknown button'))
  end
end
