class AddArchs  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv5el"
  end


  def self.down
    # too lazy too implement... resp. can't find the proper documentation...
  end


end
