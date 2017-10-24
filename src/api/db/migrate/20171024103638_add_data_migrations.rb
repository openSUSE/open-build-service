class AddDataMigrations < ActiveRecord::Migration[5.1]
  def change
    create_table :data_migrations, id: false do |t|
      t.string :version, index: {name: :unique_data_migrations, unique: true }, null: false
    end
  end
end
