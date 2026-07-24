class ReviewNotFoundError < APIError
  setup 'review_not_found', 404, 'Review not found'
end
