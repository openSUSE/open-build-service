# frozen_string_literal: true

module Webui::MainHelper
  def proceed_link(image, text, link_opts)
    content_tag(:li,
                link_to(sprite_tag(image, title: text), link_opts) + tag(:br) +
                content_tag(:span, link_to(text, link_opts), class: 'proceed_text'), id: "proceed-#{image}")
  end
end
