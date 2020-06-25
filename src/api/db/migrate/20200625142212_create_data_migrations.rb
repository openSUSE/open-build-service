# rubocop:disable Rails/CreateTableWithTimestamps
class CreateDataMigrations < ActiveRecord::Migration[6.0]
  def up
    return if ActiveRecord::Base.connection.table_exists? 'data_migrations'

    create_table :data_migrations do |t|
      t.string :version
    end
  end
end
# rubocop:enable Rails/CreateTableWithTimestamps
