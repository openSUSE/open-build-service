class ProductUpdateDependency < ActiveRecord::Migration
  def up
    create_table :product_update_repositories do |t|
      t.references :product
      t.references :repository
    end

    execute("alter table product_update_repositories add foreign key (product_id) references products(id)")
    execute("alter table product_update_repositories add foreign key (repository_id) references repositories(id)")
  end

  def down
    drop_table :product_update_repositories
  end
end
