xml.excluded_requests do
  @request_exclusions.each do |request_exclusion|
    xml.request(id: request_exclusion.bs_request.number,
                package: request_exclusion.bs_request.first_target_package,
                description: request_exclusion.description)
  end
end
