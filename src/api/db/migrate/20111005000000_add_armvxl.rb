class AddArmvxl < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv5l"
    Architecture.create :name => "armv6l"
    Architecture.create :name => "armv7l"
  end


  def self.down
    Architecture.find_by_name("armv5l").destroy
    Architecture.find_by_name("armv6l").destroy
    Architecture.find_by_name("armv7l").destroy
  end


end
