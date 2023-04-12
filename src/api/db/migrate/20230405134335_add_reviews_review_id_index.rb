class AddReviewsReviewIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :reviews, %w[review_id], name: :index_reviews_review_id, unique: true
  end
end
