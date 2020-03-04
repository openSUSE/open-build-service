module Webui::SponsorHelper
  def link_to_sponsor(sponsor_hash)
    link_to(image_tag("icons/#{sponsor_hash['icon']}.png"),
            sponsor_hash['url'],
            title: sponsor_hash['description'] || sponsor_hash['name'])
  end
end
