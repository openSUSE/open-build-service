module MainHelper

  def proceed_link(_image, _text, link_opts)
    out = "<li>"
    out += link_to(image_tag(_image), link_opts)
    out += "<br/>"
    out += link_to("<span class='proceed_text'>#{_text}</span>", link_opts)
    out += "</li>"
  end

end
