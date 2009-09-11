class AddArchs3  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv7el"
  end


  def self.down
    Architecture.find_by_name("armv7el").destroy
  end


end
