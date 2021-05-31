xml.directory(count: @list.length) do |dir|
  @list.each do |token|
    p = { id: token.id, string: token.string, kind: token.token_name }

    # TODO: Put this in the hash above once the trigger_workflow feature is completely rolled out
    if Flipper.enabled?(:trigger_workflow)
      p[:scm_token] = token.scm_token
    end

    if token.package
      p[:project] = token.package.project.name
      p[:package] = token.package.name
    end
    dir.entry(p)
  end
end
