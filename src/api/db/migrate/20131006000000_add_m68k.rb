class AddM68k < ActiveRecord::Migration


  def self.up
    Architecture.find_or_create_by_name "m68k"
  end


  def self.down
    Architecture.find_by_name("m68k").destroy
  end


end
