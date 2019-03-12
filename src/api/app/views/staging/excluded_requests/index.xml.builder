xml.excluded_requests do
  @request_exclusions.each do |request_exclusion|
    xml.request(id: request_exclusion.bs_request.number, description: request_exclusion.description)
  end
end
