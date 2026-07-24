# frozen_string_literal: true

class PrefillReviewsCountValues < ActiveRecord::Migration[7.2]
  def up
    # rubocop:disable Rails/SkipsModelValidations
    Review.group(:bs_request_id).select(:bs_request_id, 'COUNT(id) as reviews_count').each do |review|
      review.bs_request.update_columns(reviews_count: review.reviews_count)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
