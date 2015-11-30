class AddM68k < ActiveRecord::Migration
  def self.up
    Architecture.where(name: "m68k").first_or_create
  end

  def self.down
    Architecture.find_by_name("m68k").destroy
  end
end
