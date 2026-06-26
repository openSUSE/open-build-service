class AddDataMigrationsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :data_migrations, primary_key: 'version', id: false, if_not_exists: true do |t|
      t.string :version
    end
  end
end
