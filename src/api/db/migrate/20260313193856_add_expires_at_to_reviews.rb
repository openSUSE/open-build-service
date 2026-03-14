# frozen_string_literal: true

class AddExpiresAtToReviews < ActiveRecord::Migration[7.2]
  def change
    add_column :reviews, :expires_at, :datetime
    add_index :reviews, :expires_at
  end
end
