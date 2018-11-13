xml.staged_requests do
  @requests.each do |bs_request|
    xml.request(id: bs_request.number, creator: bs_request.creator, state: bs_request.state, package: bs_request.first_target_package)
  end
end
