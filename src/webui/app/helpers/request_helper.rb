module RequestHelper

  # for a simplified view on a request, must be used only for lists
  def reqtype(req)
    if req.has_element? :action
      type = req.action.value :type
    else
      type = req.value :type
    end
    type = "chgdev"   if type == "change_devel"
    type = "bugowner" if type == "set_bugowner"
    type = "addrole"  if type == "add_role"
    type = "incident" if type == "maintenance_incident"
    type = "release"  if type == "maintenance_release"
    type
  end

  STATE_ICONS = {
    'new'      => 'icons/flag_green.png',
    'review'   => 'icons/flag_yellow.png',
    'declined' => 'icons/flag_red.png',
  }

  # FIXME: belongs to CSS
  def request_state_icon(request)
    STATE_ICONS[request.state.value('name')] || ''
  end

end
