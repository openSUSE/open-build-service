module Webui::Webui2Helper
  def webui2_tab(id, text, opts, link_opts = {})
    opts[:package] = @package.to_s if @package
    opts[:project] = @project.to_s if @project
    link_opts[:id] = "tab-#{id}"
    if (action_name == opts[:action].to_s && (opts[:controller].to_s.include? controller_name)) || opts[:selected]
      link_opts[:class] = 'is-active'
    end
    content_tag('li', link_to(h(text), opts), link_opts)
  end
end
