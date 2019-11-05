class CreateAllowbuilddeps < ActiveRecord::Migration[4.2]
  def self.up
    create_table :allowbuilddeps do |t|
      t.integer :db_project_id, null: false
      t.string  :name, null: false
      t.index [:db_project_id, :name]

      t.timestamps
    end
  end

  def self.down
    drop_table :allowbuilddeps
  end
end
