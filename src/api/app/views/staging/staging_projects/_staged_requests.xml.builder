builder.staged_requests(count: count) do |staged_request|
  staged_requests.each do |bs_request|
    staged_request.entry(id: bs_request.number, creator: bs_request.creator, state: bs_request.state, package: bs_request.first_target_package)
  end
end
