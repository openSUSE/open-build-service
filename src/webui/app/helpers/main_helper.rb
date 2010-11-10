module MainHelper

  def proceed_link(_image, _text, link_opts)
    out = "<li>" + link_to(image_tag(_image), link_opts) +  "<br/>"
    out += "<span class='proceed_text'>" + link_to(h(_text), link_opts) + "</span>"
    out += "</li>"
    return out.html_safe
  end

end
