requests.each do |request|
  builder.request(id: request.number, creator: request.creator, state: request.state, package: request.first_target_package)
end
