class AddDataMigrationsTable < ActiveRecord::Migration[6.0]
  def change
    # rubocop:disable Rails/CreateTableWithTimestamps
    create_table :data_migrations, primary_key: 'version', id: false, if_not_exists: true do |t|
      t.string :version
    end
    # rubocop:enable Rails/CreateTableWithTimestamps
  end
end
