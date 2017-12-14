xml.directory(count: @list.length) do |dir|
  @list.each { |user| dir.entry(name: user.login) }
end

