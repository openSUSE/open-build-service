module Webui::GroupHelper
  def group_with_icon(group_title, opts = {})
    group = Group.find_by(title: group_title)
    link_to(user_image_tag(group, alt: group_title, css_class: opts[:css_class]), group_show_path(group)) +
      ' ' + link_to(group_title, group_show_path(group))
  end
end
