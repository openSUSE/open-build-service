# frozen_string_literal: true

class SponsorsComponent < ApplicationComponent
  def initialize(config: CONFIG)
    super
    @config = config
  end

  def sponsors?
    sponsors.present?
  end

  def sponsors
    @sponsors ||= @config.fetch('sponsors', [])
  end

  def obs_title
    ::Configuration.title
  end

  def link_to_sponsor(sponsor_hash)
    link_to(image_tag("icons/#{sponsor_hash['icon']}.png"),
            sponsor_hash['url'],
            title: sponsor_hash['description'] || sponsor_hash['name'])
  end
end
