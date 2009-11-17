class AddArchs2  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "armv5el"
  end


  def self.down
    arch = Architecture.find_by_name("armv5el")
    if arch
      arch.destroy
    end
  end


end
