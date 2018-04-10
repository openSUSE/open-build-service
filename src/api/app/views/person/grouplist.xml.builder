# frozen_string_literal: true

xml.directory(count: @list.length) do |dir|
  @list.each do |g|
    dir.entry(name: g.title)
  end
end
