class CreateConfigurations < ActiveRecord::Migration
  def self.up
    # to help people who updated during development phase
    begin
      drop_table :configurations
    rescue
      pass
    end

    create_table :configurations do |t|
      t.string :nameprefix
      t.text :description

      t.timestamps
    end
  end

  def self.down
    drop_table :configurations
  end
end
