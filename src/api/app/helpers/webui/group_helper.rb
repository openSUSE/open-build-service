module Webui::GroupHelper
  def group_with_icon(group_title)
    group = Group.find_by(title: group_title)
    image_tag_for(group, size: 20) + ' ' + link_to(group_title, group_path(group))
  end
end
