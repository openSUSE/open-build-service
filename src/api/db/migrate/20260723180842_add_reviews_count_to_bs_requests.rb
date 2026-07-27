class AddReviewsCountToBsRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :bs_requests, :reviews_count, :integer, default: 0, null: false
    add_index :bs_requests, :reviews_count
  end
end
