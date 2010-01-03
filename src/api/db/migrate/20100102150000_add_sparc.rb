class AddSparc  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "sparcv8"
    Architecture.create :name => "sparcv9"
  end


  def self.down
    Architecture.find_by_name("sparcv8").destroy
    Architecture.find_by_name("sparcv9").destroy
  end

end
