# filter and render them
issues.each do |i|
  change = nil
  change = i.change if i.instance_of?(PackageIssue)
  next if @filter_changes && (!change || @filter_changes.exclude?(change))
  next if @states && (!i.issue.state || @states.exclude?(i.issue.state))

  o = nil
  if i.issue.owner_id
    # self.owner must not by used, since it is reserved by rails
    o = User.find i.issue.owner_id
  end
  next if @login && (!o || @login != o.login)

  i.issue.render_body(builder, change)
end
