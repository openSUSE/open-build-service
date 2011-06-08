class CreateConfigurations2 < ActiveRecord::Migration
  def self.up
    create_table :configurations do |t|
      t.string :title
      t.text :description

      t.timestamps
    end
  end

  def self.down
    drop_table :configurations
  end
end
