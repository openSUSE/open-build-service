class CreateFlags < ActiveRecord::Migration
  def self.up
    create_table :flags do |t|
      t.column :status, :string
      t.column :type, :string
      t.column :repo, :string
      t.column :db_project_id, :integer
      t.column :db_package_id, :integer
      t.column :architecture_id, :integer
      t.column :position, :integer
    end
  end

  def self.down
    drop_table :flags
  end
end
