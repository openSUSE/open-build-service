class AddArmv7hl < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv7hl"
  end


  def self.down
    arch = Architecture.find_by_name("armv7hl")
    if arch
       arch.destroy
    end
  end


end
