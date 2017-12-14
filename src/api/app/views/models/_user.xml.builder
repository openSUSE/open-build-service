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

  # Show the watchlist only to the user for privacy reasons
  if watchlist
    xml.watchlist do
      my_model.watched_projects.each do |wp|
        xml.project(name: wp.project.name)
      end
    end
  end
end
