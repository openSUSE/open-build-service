class BuildStatusBadgeComponent < ApplicationComponent
  def initialize(status:, text:, url: nil)
    super

    @status = status
    @text = text
    @url = url
    @category = Buildresult::BUILD_STATUS_CATEGORIES_MAP[status]
  end

  ICON = {
    succeeded: 'fa-check',
    failed: 'fa-circle-exclamation',
    unresolvable: 'fa-circle-exclamation',
    broken: 'fa-circle-exclamation',
    blocked: 'fa-shield',
    scheduled: 'fa-hourglass-half',
    dispatching: 'fa-plane-departure',
    building: 'fa-gear',
    signing: 'fa-signature',
    finished: 'fa-check',
    disabled: 'fa-ban',
    excluded: 'fa-ban',
    locked: 'fa-lock',
    deleting: 'fa-eraser',
    unknown: 'fa-question'
  }.with_indifferent_access.freeze

  def badge
    badge_color = BuildStatusCountBadgeComponent::CATEGORY_BADGE_COLOR[@category]
    if @url
      link_to(icon.concat(@text), @url, class: ['badge', badge_color, 'clickable'], title: 'Live build log')
    else
      tag.span(icon.concat(@text), class: ['badge', badge_color])
    end
  end

  def icon
    tag.i(class: ['fa', ICON[@status], 'me-2'], title: @status.humanize)
  end
end
