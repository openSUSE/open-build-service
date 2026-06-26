elements.each do |element|
  builder.entry(event_type: element.event_type.humanize, request: element.bs_request.number,
                package: element.package_name, author: element.user_name)
end
