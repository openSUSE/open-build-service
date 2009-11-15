class CreateStatusHistories < ActiveRecord::Migration
  def self.up
    create_table :status_histories do |t|
      t.integer :time
      t.string :key
      t.integer :value

      t.timestamps
    end
  end

  def self.down
    drop_table :status_histories
  end
end
