# frozen_string_literal: true

class AddReviewIdToReview < ActiveRecord::Migration[5.0]
  def change
    add_reference :reviews, :review, index: true, foreign_key: true
  end
end
