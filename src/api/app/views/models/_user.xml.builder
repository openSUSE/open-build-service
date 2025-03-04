if render_watchlist_only
  render partial: 'person/watchlist', locals: { builder: xml, my_model: my_model }
else
  xml.person do
    xml.login(my_model.login)
    xml.email(my_model.email)
    realname = my_model.realname
    unless realname.nil?
      realname.toutf8
      xml.realname(realname)
    end
    xml.owner(userid: my_model.owner.login) if my_model.owner
    xml.state(my_model.state)

    my_model.roles.global.each do |role|
      xml.globalrole(role.title)
    end

    xml.ignore_auth_services(my_model.ignore_auth_services) if my_model.admin?

    # Show the watchlist only to the user for privacy reasons
    render partial: 'person/watchlist', locals: { builder: xml, my_model: my_model } if watchlist
  end
end
