# frozen_string_literal: true

class ReviewExpirationJob < ApplicationJob
  queue_as :default

  def perform
    Review.expired.find_each do |review|
      review.bs_request.expire_review(review)
    end
  end
end
