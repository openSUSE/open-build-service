xml.directory(count: @list.length) do
  @list.order(title: :asc).each do |group|
    xml.entry(name: group.title)
  end
end
