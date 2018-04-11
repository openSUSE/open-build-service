# frozen_string_literal: true

class ProductMediaTracking < ActiveRecord::Migration[4.2]
  def up
    create_table :product_media do |t|
      t.references :product
      t.references :repository
      t.string :medium
    end

    execute('alter table product_media add foreign key (product_id) references products(id)')
    execute('alter table product_media add foreign key (repository_id) references repositories(id)')
  end

  def down
    drop_table :product_media
  end
end
