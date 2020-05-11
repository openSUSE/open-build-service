xml.directory(count: @packages.count) do
  @packages.map do |name, project|
    if expand
      xml.entry(name: name, originproject: project)
    else
      xml.entry(name: name)
    end
  end
end
