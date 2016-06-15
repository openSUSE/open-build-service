module Webui::MainHelper
  def proceed_link(_image, _text, link_opts)
    content_tag(:li,
                link_to(sprite_tag(_image, title: _text), link_opts) + tag(:br) +
                content_tag(:span, link_to(_text, link_opts), class: 'proceed_text'), id: "proceed-#{_image}")
  end
end
