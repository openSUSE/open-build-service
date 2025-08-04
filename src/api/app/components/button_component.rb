class ButtonComponent < ApplicationComponent
  renders_one :text

  def initialize(type: nil, text: nil, css_custom: '', icon_type: nil, button_data: {})
    super

    @type = type
    @text = text
    @css_custom = css_custom
    @icon_type = icon_type
    @button_data = button_data
  end

  def css_style
    (@type ? "btn-#{@type} " : 'btn-secondary ') << @css_custom
  end

  def icon
    "fa-#{@icon_type} #{'me-1' if @text} " if @icon_type
  end
end
