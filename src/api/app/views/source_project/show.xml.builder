xml.directory(count: @packages.count) do
  @packages.sort_by(&:name).map do |package, project|
    if expand
      xml.entry(name: package.name, originproject: project)
    elsif package.multibuild?
      xml.entry(name: package.name)
      package.multibuild_flavors.each do |flavor|
        xml.entry(name: "#{package.name}:#{flavor}", originpackage: package.name)
      end
    else
      xml.entry(name: package.name)
    end
  end
end
