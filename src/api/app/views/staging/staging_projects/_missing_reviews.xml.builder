builder.missing_reviews(count: count) do |missing_review|
  missing_reviews.each do |review|
    missing_review.review(request: review[:request], state: review[:state], package: review[:package],
                          creator: review[:creator], review[:review_type] => review[:by])
  end
end
