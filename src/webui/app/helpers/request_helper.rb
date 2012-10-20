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

  def request_state_icon(request)
    case request.get('state')['name']
      when 'new' then return 'flag_green'
      when 'review' then return 'flag_yellow'
      when 'declined' then return'flag_red'
      else return ''
    end
  end

end
