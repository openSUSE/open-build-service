xml.directory(count: packages.count) do
  packages.map do |package|
    if expand
      xml.entry(name: package[0], originproject: package[1])
    else
      xml.entry(name: package)
    end
  end
end
