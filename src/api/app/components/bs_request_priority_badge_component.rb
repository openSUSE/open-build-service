class BsRequestPriorityBadgeComponent < ApplicationComponent
  attr_reader :priority, :css_class

  def initialize(priority:, css_class: nil)
    super

    @priority = priority
    @css_class = css_class
  end

  def call
    content_tag(:span, priority, class: ['badge', "text-bg-#{decode_priority_color}", css_class])
  end

  def decode_priority_color
    case priority
    when 'moderate'
      'success'
    when 'important'
      'warning'
    when 'critical'
      'danger'
    else
      'dark'
    end
  end
end
