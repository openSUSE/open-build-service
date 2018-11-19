builder.requests_to_review(count: count) do
  requests_to_review.each do |bs_request|
    builder.entry(id: bs_request.number, creator: bs_request.creator, state: bs_request.state, package: bs_request.first_target_package)
  end
end
