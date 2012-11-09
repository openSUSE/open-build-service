module RequestHelper

  # for a simplified view on a request, must be used only for lists
  def reqtype(req)
    type = req['type']
    type = "chgdev"   if type == "change_devel"
    type = "bugowner" if type == "set_bugowner"
    type = "addrole"  if type == "add_role"
    type = "incident" if type == "maintenance_incident"
    type = "release"  if type == "maintenance_release"
    type
  end

  STATE_ICONS = {
    'new'      => 'flag_green',
    'review'   => 'flag_yellow',
    'declined' => 'flag_red',
  }

  def map_request_state_to_flag(state)
    STATE_ICONS[state] || ''
  end

end
