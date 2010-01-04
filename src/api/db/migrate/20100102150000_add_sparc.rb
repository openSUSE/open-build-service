class AddSparc  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "sparcv8"
    Architecture.create :name => "sparcv9"
    Architecture.create :name => "sparcv9v"
    Architecture.create :name => "sparc64v"
  end


  def self.down
    Architecture.find_by_name("sparcv8").destroy
    Architecture.find_by_name("sparcv9").destroy
    Architecture.find_by_name("sparcv9v").destroy
    Architecture.find_by_name("sparc64v").destroy
  end

end
