class FixProductMediaUniqIndex < ActiveRecord::Migration
  def self.up
    execute("alter table product_media drop foreign key `product_media_ibfk_1`")
    execute("alter table product_media drop foreign key `product_media_ibfk_2`")
    execute("alter table product_media drop foreign key `product_media_ibfk_3`")

    remove_index :product_media, unique: true, :name => "index_unique"
    remove_index :product_update_repositories, unique: true, :name => "index_unique"

    add_index :product_media, [:product_id, :repository_id, :name, :arch_filter_id], unique: true, :name => "index_unique"
    add_index :product_update_repositories, [:product_id, :repository_id, :arch_filter_id], unique: true, :name => "index_unique"

    execute("alter table product_media add FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)")
    execute("alter table product_media add FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`)")
    execute("alter table product_media add FOREIGN KEY (`arch_filter_id`) REFERENCES `architectures` (`id`)")
  end

  def self.down
    execute("alter table product_media drop foreign key `product_media_ibfk_1`")
    execute("alter table product_media drop foreign key `product_media_ibfk_2`")
    execute("alter table product_media drop foreign key `product_media_ibfk_3`")
    remove_index :product_media, unique: true, :name => "index_unique"
    remove_index :product_update_repositories, unique: true, :name => "index_unique"

    add_index :product_media, [:product_id, :repository_id, :name], unique: true, :name => "index_unique"
    add_index :product_update_repositories, [:product_id, :repository_id], unique: true, :name => "index_unique"
    execute("alter table product_media add FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)")
    execute("alter table product_media add FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`)")
    execute("alter table product_media add FOREIGN KEY (`arch_filter_id`) REFERENCES `architectures` (`id`)")
  end
end
