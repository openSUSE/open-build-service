class AddLocalArch  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "local"
  end


  def self.down
    # too lazy too implement... resp. can't find the proper documentation...
  end


end
