module Webui::GroupHelper
  def group_with_icon(group_title)
    group = Group.find_by(title: group_title)
    user_image_tag(group, alt: group_title) + ' ' + link_to(group_title, group_show_path(group))
  end
end
