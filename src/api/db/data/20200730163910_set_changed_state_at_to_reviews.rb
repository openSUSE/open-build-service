class SetChangedStateAtToReviews < ActiveRecord::Migration[6.0]
  def up
    Review.where(changed_state_at: nil).find_each(batch_size: 5000) do |review|
      # rubocop:disable-next Rails/SkipsModelValidations
      review.update_columns(changed_state_at: review.updated_at)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
