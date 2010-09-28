class AddArchs4 < ActiveRecord::Migration


  def self.up
    Architecture.find_or_create_by_name "athlon"
    Architecture.find_or_create_by_name "i386"
    Architecture.find_or_create_by_name "i486"
    Architecture.find_or_create_by_name "sh4"
  end


  def self.down
    Architecture.find_by_name("athlon").destroy
    Architecture.find_by_name("i386").destroy
    Architecture.find_by_name("i486").destroy
    Architecture.find_by_name("sh4").destroy
  end


end
