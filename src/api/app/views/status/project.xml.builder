
xml.packages do
  @packages.each_value do |package|
    render(partial: 'package', locals: { builder: xml, package: package })
  end
end
