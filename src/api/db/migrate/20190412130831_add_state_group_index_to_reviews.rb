class AddStateGroupIndexToReviews < ActiveRecord::Migration[5.2]
  def change
    add_index :reviews, [:state, :by_group]
  end
end
