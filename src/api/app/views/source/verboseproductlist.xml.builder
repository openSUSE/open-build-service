# avoid to render, parser and re-render here, since it can be a hughe content

output = ''
output << "<productlist count='#{@products.length}'>\n"
@products.each do |p|
  output << p.to_axml
end
output << "</productlist>\n"
return output
