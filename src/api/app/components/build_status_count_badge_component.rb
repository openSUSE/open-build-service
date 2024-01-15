class BuildStatusCountBadgeComponent < ApplicationComponent
  def initialize(category:, count:)
    super

    @category = category
    @count = count.to_s
  end

  CATEGORY_ICON = {
    succeeded: 'fa-check',
    failed: 'fa-circle-exclamation',
    blocked: 'fa-shield',
    processing: 'fa-gear',
    disabled: 'fa-ban'
  }.with_indifferent_access.freeze

  CATEGORY_BADGE_COLOR = {
    succeeded: 'text-bg-success',
    failed: 'text-bg-danger',
    blocked: 'text-bg-warning',
    processing: 'text-bg-info',
    disabled: 'text-bg-light border'
  }.with_indifferent_access.freeze

  def badge
    tag.span(icon.concat(@count), class: ['badge', CATEGORY_BADGE_COLOR[@category]])
  end

  def icon
    tag.i(class: ['fa', CATEGORY_ICON[@category], 'me-2'])
  end
end
