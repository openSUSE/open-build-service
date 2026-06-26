class AddChangedStateAtToReviews < ActiveRecord::Migration[6.0]
  def change
    add_column :reviews, :changed_state_at, :datetime
  end
end
