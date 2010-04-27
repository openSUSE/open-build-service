class AddArm < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv6el"
    Architecture.create :name => "armv8el"
  end


  def self.down
    Architecture.find_by_name("armv6el").destroy
    Architecture.find_by_name("armv8el").destroy
  end


end
