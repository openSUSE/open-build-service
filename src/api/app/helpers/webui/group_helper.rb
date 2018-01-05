module Webui::GroupHelper
  def group_management_label
    if User.current.is_admin?
      link_to('Group Management', groups_path)
    else
      'Group Management'
    end
  end
end
