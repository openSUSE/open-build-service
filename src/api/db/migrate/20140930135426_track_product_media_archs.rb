class TrackProductMediaArchs < ActiveRecord::Migration
  def self.up
    add_column :product_media, :arch_filter_id, :integer
    add_column :product_update_repositories, :arch_filter_id, :integer

    add_index :product_media, :arch_filter_id
    add_index :product_update_repositories, :arch_filter_id

    execute("alter table product_media add foreign key (arch_filter_id) references architectures(id)")
    execute("alter table product_update_repositories add foreign key (arch_filter_id) references architectures(id)")
  end

  def self.down
    execute("alter table product_media drop FOREIGN KEY product_media_ibfk_3")
    execute("alter table product_update_repositories drop FOREIGN KEY product_update_repositories_ibfk_3")

    remove_index :product_media, :arch_filter_id
    remove_index :product_update_repositories, :arch_filter_id

    remove_column :product_media, :arch_filter_id
    remove_column :product_update_repositories, :arch_filter_id
  end
end
