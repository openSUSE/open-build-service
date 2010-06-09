class AddMips < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "mipsel"
    Architecture.create :name => "mips64el"
  end


  def self.down
    Architecture.find_by_name("mipsel").destroy
    Architecture.find_by_name("mips64el").destroy
  end


end
