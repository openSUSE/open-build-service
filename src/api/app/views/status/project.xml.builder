
xml.instruct!

xml.packages do
  @packages.each do |name,pkg|
    pkg.to_xml(:builder => xml)
  end
end

