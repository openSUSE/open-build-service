class BsRequestStateBadgeComponent < ApplicationComponent
  attr_reader :state, :css_class

  def initialize(state:, css_class: nil)
    super

    @state = state
    @css_class = css_class
  end

  def call
    content_tag(
      :span,
      icon_state_tag.concat(state.to_s),
      class: ['badge', "text-bg-#{decode_state_color}", css_class]
    )
  end

  def decode_state_color
    case state
    when :review, :new
      'secondary'
    when :declined
      'danger'
    when :superseded
      'warning'
    when :accepted
      'success'
    when :revoked
      'dismissed'
    else
      'dark'
    end
  end

  private

  def decode_state_icon
    case state
    when :new
      'code-branch'
    when :review, :declined, :revoked
      'code-pull-request'
    when :superseded
      'code-compare'
    when :accepted
      'code-merge'
    else
      'code-fork'
    end
  end

  def icon_state_tag
    if %i[declined revoked].include?(state)
      content_tag(
        :span,
        tag.i(class: 'fas fa-code-pull-request').concat(
          tag.i(class: 'fas fa-times fa-xs')
        ),
        class: 'fa-custom-pr-closed me-1'
      )
    else
      tag.i(class: "fas fa-#{decode_state_icon} me-1")
    end
  end
end
