xml.reviews do
  @reviews.each do |review|
    xml.request(id: review.number, creator: review.creator, state: review.state, package: review.first_target_package)
  end
end
