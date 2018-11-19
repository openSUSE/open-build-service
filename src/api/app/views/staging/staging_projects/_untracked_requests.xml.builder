builder.untracked_requests(count: count) do |untracked_request|
  untracked_requests.each do |bs_request|
    untracked_request.entry(id: bs_request.number, creator: bs_request.creator, state: bs_request.state, package: bs_request.first_target_package)
  end
end
