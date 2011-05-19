class CreateDbProjectTypes < ActiveRecord::Migration
  def self.up
    create_table :db_project_types do |t|
      t.string :name, :null => false
    end
  end

  def self.down
    drop_table :db_project_types
  end
end
