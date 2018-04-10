# frozen_string_literal: true
class CreateKiwiDescriptions < ActiveRecord::Migration[5.1]
  def change
    create_table :kiwi_descriptions, id: :integer do |t|
      t.references :image, type: :integer
      t.integer :description_type, default: 0
      t.string :author
      t.string :contact
      t.string :specification

      t.timestamps
    end
  end
end
