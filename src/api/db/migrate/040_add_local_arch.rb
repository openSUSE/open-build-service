class AddLocalArch  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "local"
  end


  def self.down
    Architecture.find_by_name("local").destroy
  end


end
