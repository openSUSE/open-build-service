class BsRequestPriorityBadgeComponent < ApplicationComponent
  attr_reader :css_class, :overview

  def initialize(priority:, css_class: nil, overview: false)
    super

    @priority = priority
    @css_class = css_class
    @overview = overview
  end

  def call
    return if overview && @priority == 'moderate'

    @priority = "#{@priority} priority" if overview && @priority == 'low'

    content_tag(:span, @priority, class: ['badge', "text-bg-#{decode_priority_color}", css_class])
  end

  def decode_priority_color
    case @priority
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
