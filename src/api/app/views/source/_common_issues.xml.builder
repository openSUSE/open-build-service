# filter and render them
issues.each do |i|
  change = nil
  change = i.change if i.class == PackageIssue
  next if @filter_changes and (not change or not @filter_changes.include? change)
  next if @states and (not i.issue.state or not @states.include? i.issue.state)
  o = nil
  if i.issue.owner_id
    # self.owner must not by used, since it is reserved by rails
    o = User.find i.issue.owner_id
  end
  next if @login and (not o or not @login == o.login)
  i.issue.render_body(builder, change)
end
