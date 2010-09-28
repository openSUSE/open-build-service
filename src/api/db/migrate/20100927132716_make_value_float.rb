class MakeValueFloat < ActiveRecord::Migration
  def self.up
    change_column :status_histories, :value, :float, :null => false
  end

  def self.down
    change_column :status_histories, :value, :integer
  end
end
