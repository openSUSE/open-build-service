class BsRequestStateBadgeComponent < ApplicationComponent
  def initialize(bs_request:, css_class: nil)
    super

    @bs_request = bs_request
    @css_class = css_class
  end

  def call
    content_tag(
      :span,
      tag.i(class: 'fas fa-code-pull-request me-1').concat(@bs_request.state),
      class: ['badge', "bg-#{decode_state_color(@bs_request.state)}", @css_class]
    )
  end

  def decode_state_color(state)
    case state
    when :review, :new
      'secondary'
    when :declined, :revoke
      'danger'
    when :superseded
      'warning'
    when :accepted
      'success'
    else
      'dark'
    end
  end
end
