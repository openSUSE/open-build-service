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

  def request_state_icon(request)
    case request.state.value('name')
      when 'new' then return 'icons/flag_green.png'
      when 'review' then return 'icons/flag_yellow.png'
      when 'declined' then return'icons/flag_red.png'
      else return ''
    end
  end

end
