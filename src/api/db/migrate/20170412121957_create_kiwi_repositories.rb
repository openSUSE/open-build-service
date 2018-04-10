# frozen_string_literal: true

class CreateKiwiRepositories < ActiveRecord::Migration[5.0]
  def change
    create_table :kiwi_repositories do |t|
      t.references :image
      t.string :repo_type
      t.string :source_path
      t.integer :order
      t.integer :priority

      t.timestamps

      t.index([:image_id, :order], unique: true)
    end
  end
end
