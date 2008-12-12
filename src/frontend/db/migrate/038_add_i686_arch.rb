class AddI686Arch  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "i686"
    Architecture.create :name => "mips64"
    Architecture.create :name => "mips32"
  end


  def self.down
    # too lazy too implement... resp. can't find the proper documentation...
  end


end
