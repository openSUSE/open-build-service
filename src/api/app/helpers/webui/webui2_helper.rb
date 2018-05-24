module Webui::Webui2Helper
  def webui2_tab(id, text, opts, link_opts = {})
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s if @project
    link_opts[:id] = "tab-#{id}"
    link_opts[:class] = "nav-link"
    if (action_name == opts[:action].to_s && (opts[:controller].to_s.include? controller_name)) || opts[:selected]
      link_opts[:class] = 'nav-link active'
    end
    content_tag('li', link_to(h(text), opts, link_opts), class: 'nav-item')
  end
  def proceed_link_webui2(image, text, link_opts)
    content_tag(:li,
                link_to(sprite_tag(image, title: text, class: 'mx-auto d-block') + content_tag(:p, text, class: 'mx-auto') , link_opts, class: 'nav-link'), id: "proceed-#{image}", class: 'nav-item')
  end
end
