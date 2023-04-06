class BsRequestStateBadgeComponent < ApplicationComponent
  def initialize(bs_request:, css_class: nil)
    super

    @bs_request = bs_request
    @css_class = css_class
  end

  def call
    content_tag(
      :span,
      icon_state_tag.concat(@bs_request.state),
      class: ['badge', "bg-#{decode_state_color(@bs_request.state)}", @css_class]
    )
  end

  def decode_state_color(state)
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

  def decode_state_icon(state)
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
    if [:declined, :revoked].include?(@bs_request.state)
      content_tag(
        :span,
        tag.i(class: "fas fa-#{decode_state_icon(@bs_request.state)}").concat(
          tag.i(class: 'fas fa-slash fa-stack-1x fa-stack-slash top-icon')
        ),
        class: 'position-relative me-1'
      )
    else
      tag.i(class: "fas fa-#{decode_state_icon(@bs_request.state)} me-1")
    end
  end
end
