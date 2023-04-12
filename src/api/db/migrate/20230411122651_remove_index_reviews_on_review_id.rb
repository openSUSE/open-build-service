class RemoveIndexReviewsOnReviewId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'reviews', 'review_id', name: 'index_reviews_on_review_id'
  end
end
