# frozen_string_literal: true

class PrefillReviewsCountValues < ActiveRecord::Migration[7.2]
  def up
    # rubocop:disable Rails/SkipsModelValidations
    BsRequest.in_batches do |batch|
      ids = batch.pluck(:id)
      counts = Review.where(bs_request_id: ids).group(:bs_request_id).count # Returns a hash with key-values like request_id => number_of_reviews
      counts.each do |bs_request_id, count|
        BsRequest.where(id: bs_request_id).update_all(reviews_count: count)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
