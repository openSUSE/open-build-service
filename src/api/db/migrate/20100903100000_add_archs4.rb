class AddArchs4 < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "athlon"
    Architecture.create :name => "i386"
    Architecture.create :name => "i486"
    Architecture.create :name => "sh4"
  end


  def self.down
    Architecture.find_by_name("athlon").destroy
    Architecture.find_by_name("i386").destroy
    Architecture.find_by_name("i486").destroy
    Architecture.find_by_name("sh4").destroy
  end


end
