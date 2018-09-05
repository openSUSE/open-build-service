class ChangeProjectPackageNameToString < ActiveRecord::Migration[5.0]
  def change
    execute 'UPDATE projects SET name = SUBSTR(name, 1, 200)'
    execute 'UPDATE projects SET name = "" WHERE name is null'
    execute 'UPDATE packages SET name = SUBSTR(name, 1, 200)'
    execute 'UPDATE packages SET name = "" WHERE name is null'
    begin
      change_column :projects, :name, :string, limit: 200, null: false
    rescue StandardError
      execute 'ALTER TABLE projects DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'
      change_column :projects, :name, :string, limit: 200, null: false
    end
    begin
      change_column :packages, :name, :string, limit: 200, null: false
    rescue StandardError
      execute 'ALTER TABLE packages DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'
      change_column :packages, :name, :string, limit: 200, null: false
    end
  end
end
