xml.directory(count: @list.length) do |dir|
  @list.each do |token|
    token_name = token.token_name.sub('service', 'runservice') # To make token naming consistent: we create the token as runservice
    p = { id: token.id, string: token.string, kind: token_name, description: token.description, enabled: token.enabled, triggered_at: token.triggered_at }
    if token.package
      p[:project] = token.package.project.name
      p[:package] = token.package.name
    end
    dir.entry(p)
  end
end
