builder.missing_reviews(count: count) do |missing_review|
  missing_reviews.each do |bs_request|
    missing_review.entry(id: bs_request[:id], creator: bs_request[:by], state: bs_request[:state], package: bs_request[:package])
  end
end
