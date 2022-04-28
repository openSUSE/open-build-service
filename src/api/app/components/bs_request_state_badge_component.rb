class BsRequestStateBadgeComponent < ApplicationComponent
  def initialize(bs_request:, css_class: nil)
    super

    @bs_request = bs_request
    @css_class = css_class
  end

  def call
    tag.span(@bs_request.state,
             class: ['badge', "badge-#{helpers.request_badge_color(@bs_request.state)}", @css_class])
  end
end
