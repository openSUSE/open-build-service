class AddHppa  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "hppa"
  end


  def self.down
    arch = Architecture.find_by_name("hppa")
    if arch
       arch.destroy
    end
  end


end
