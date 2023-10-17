class ButtonComponent < ApplicationComponent
  renders_one :text

  def initialize(type: nil, id: nil, text: nil, css_custom: '', icon_type: nil,
                 button_data: {}, aria_data: {}, html_type: nil, html_disabled: nil,
                 html_value: nil, title: nil)
    super

    @type = type
    @id = id
    @text = text
    @css_custom = css_custom
    @icon_type = icon_type
    @button_data = button_data
    @html_type = html_type
    @html_disabled = html_disabled
    @html_value = html_value
    @title = title
  end

  def css_style
    (@type ? "btn-#{@type} " : 'btn-secondary ') << @css_custom
  end

  def icon
    "fa-#{@icon_type} #{'me-1' if @text} " if @icon_type
  end
end
