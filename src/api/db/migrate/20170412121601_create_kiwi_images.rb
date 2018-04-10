# frozen_string_literal: true
class CreateKiwiImages < ActiveRecord::Migration[5.0]
  def change
    create_table :kiwi_images do |t|
      t.string :name
      t.string :md5_last_revision, limit: 32

      t.timestamps
    end
  end
end
