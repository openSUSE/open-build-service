class ProductAndChannelSetup < ActiveRecord::Migration
  def up
    transaction do
      create_table :products do |t|
        t.string :name, null: false
        t.belongs_to :package, null: false
      end

      create_table :channels do |t|
        # FIXME: channel name should get calculated automatically
        t.belongs_to :package, null: false
      end

      create_table :product_channels do |t|
        t.belongs_to :product, null: false
        t.belongs_to :channel, null: false
      end

      create_table :channel_targets do |t|
        t.belongs_to :channel, null: false
        t.belongs_to :repository, null: false
      end

      create_table :channel_binary_lists do |t|
        # FIXME: identifier?
        t.belongs_to :channel, null: false
        t.belongs_to :project
        t.belongs_to :repository
        t.belongs_to :architecture
      end

      create_table :channel_binaries do |t|
        t.string :name, null: false
        t.belongs_to :channel_binary_list, null: false
        t.belongs_to :project
        t.belongs_to :repository
        t.belongs_to :architecture
        t.string :package # may not exist yet due to project links
        t.string :binaryarch
      end

      add_index :products, [:name, :package_id], unique: true
      add_index :product_channels, [:channel_id, :product_id], unique: true
      add_index :channel_targets, [:channel_id, :repository_id], unique: true
      add_index :channel_binaries, [:name, :channel_binary_list_id], unique: true
      add_index :channel_binaries, [:project_id, :package]

      execute "alter table products add FOREIGN KEY (package_id) references packages (id);"
      execute "alter table channels add FOREIGN KEY (package_id) references packages (id);"

      execute "alter table product_channels add FOREIGN KEY (channel_id) references channels (id);"
      execute "alter table product_channels add FOREIGN KEY (product_id) references products (id);"

      execute "alter table channel_targets add FOREIGN KEY (channel_id) references channels (id);"
      execute "alter table channel_targets add FOREIGN KEY (repository_id) references repositories (id);"

      execute "alter table channel_binary_lists add FOREIGN KEY (channel_id) references channels (id);"
      execute "alter table channel_binary_lists add FOREIGN KEY (project_id) references projects (id);"
      execute "alter table channel_binary_lists add FOREIGN KEY (repository_id) references repositories (id);"
      execute "alter table channel_binary_lists add FOREIGN KEY (architecture_id) references architectures (id);"

      execute "alter table channel_binaries add FOREIGN KEY (channel_binary_list_id) references channel_binary_lists (id);"
      execute "alter table channel_binaries add FOREIGN KEY (project_id) references projects (id);"
      execute "alter table channel_binaries add FOREIGN KEY (repository_id) references repositories (id);"
      execute "alter table channel_binaries add FOREIGN KEY (architecture_id) references architectures (id);"

      # introduce product and channel as package kind
      execute "alter table package_kinds modify column kind enum('patchinfo', 'aggregate', 'link', 'channel', 'product') not null;"
    end
  end

  def down
    transaction do
      drop_table :channel_binaries
      drop_table :channel_targets
      drop_table :channel_binary_lists
      drop_table :product_channels
      drop_table :channels
      drop_table :products

      execute "alter table package_kinds modify column kind enum('patchinfo', 'aggregate', 'link') not null;"
    end
  end
end
