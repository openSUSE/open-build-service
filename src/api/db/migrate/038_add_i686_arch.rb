class AddI686Arch  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "i686"
    Architecture.create :name => "mips64"
    Architecture.create :name => "mips32"
  end


  def self.down
    Architecture.find_by_name("i686").destroy
    Architecture.find_by_name("mips32").destroy
    Architecture.find_by_name("mips64").destroy
  end


end
