# frozen_string_literal: true

class PatchinfoComponent < ApplicationComponent
  attr_reader :patchinfo, :path, :release_targets, :binaries, :packages, :issues

  CATEGORY_COLOR = { ptf: 'text-bg-danger',
                     security: 'text-bg-warning',
                     recommended: 'text-bg-info',
                     optional: 'text-bg-secondary',
                     feature: 'text-bg-success' }.freeze

  RATING_COLOR = { low: 'text-bg-secondary',
                   moderate: 'text-bg-success',
                   important: 'text-bg-warning',
                   critical: 'text-bg-danger' }.freeze

  def initialize(patchinfo, path)
    super
    @patchinfo = Xmlhash.parse(patchinfo)
    @path = path

    @release_targets = [@patchinfo['releasetarget']].flatten
    @binaries = [@patchinfo['binary']].flatten
    @packages = [@patchinfo['package']].flatten
    @issues = [@patchinfo['issue']].flatten
  end

  def category
    badge(patchinfo['category'], CATEGORY_COLOR[patchinfo['category'].to_sym])
  end

  def rating
    badge("#{patchinfo['rating']} priority", RATING_COLOR[patchinfo['rating'].to_sym])
  end

  def stopped
    return '' unless @patchinfo['stopped']

    badge('stopped', 'text-bg-danger')
  end

  def retracted
    return '' unless @patchinfo['retracted']

    badge('retracted', 'text-bg-danger')
  end

  def properties
    %w[reboot_needed relogin_needed zypp_restart_needed].filter_map do |property|
      patchinfo.key?(property) ? property : nil
    end
  end

  def render?
    patchinfo.present?
  end

  private

  def badge(text, color = 'text-bg-secondary')
    tag.span(text.humanize, class: "badge #{color}")
  end
end
