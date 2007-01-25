class AddArchs  < ActiveRecord::Migration


  def self.up
    Architecture.create :name => "ppc"
    Architecture.create :name => "ppc64"
    Architecture.create :name => "s390"
    Architecture.create :name => "s390x"
    Architecture.create :name => "ia64"
    Architecture.create :name => "mips"
    Architecture.create :name => "armv4l"
    Architecture.create :name => "sparc"
    Architecture.create :name => "sparc64"
  end


  def self.down
    # too lazy too implement... resp. can't find the proper documentation...
  end


end
