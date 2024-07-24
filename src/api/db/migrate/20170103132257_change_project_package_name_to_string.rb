class ChangeProjectPackageNameToString < ActiveRecord::Migration[5.0]
  def up
    execute 'UPDATE projects SET name = SUBSTR(name, 1, 200)'
    execute 'UPDATE projects SET name = "" WHERE name is null'
    execute 'UPDATE packages SET name = SUBSTR(name, 1, 200)'
    execute 'UPDATE packages SET name = "" WHERE name is null'
    change_column :projects, :name, :string, limit: 200, null: false
    change_column :packages, :name, :string, limit: 200, null: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
