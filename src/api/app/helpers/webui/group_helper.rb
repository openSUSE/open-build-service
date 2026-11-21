module Webui::GroupHelper
  def group_with_icon(group_or_title)
    # Edge case: accept either a Group record or a string title, avoiding redundant queries
    group = group_or_title.is_a?(Group) ? group_or_title : Group.find_by(title: group_or_title)
    return group_or_title.to_s unless group

    safe_join([image_tag_for(group, size: 20), ' ', link_to(group.title, group_path(group))])
  end
end
