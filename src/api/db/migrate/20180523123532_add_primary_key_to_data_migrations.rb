class AddPrimaryKeyToDataMigrations < ActiveRecord::Migration[5.2]
  def up
    change_column :data_migrations, :version, :string, limit: 255, primary_key: true if primary_keys(:data_migrations).empty?
    return unless index_exists?(:data_migrations, :version, name: :unique_data_migrations)
    remove_index :data_migrations, name: :unique_data_migrations
  end

  def down
    execute('alter table data_migrations DROP PRIMARY KEY') unless primary_keys(:data_migrations).empty?
    return if index_exists?(:data_migrations, :version, name: :unique_data_migrations)
    add_index :data_migrations, :version, name: :unique_data_migrations, unique: true
  end
end
