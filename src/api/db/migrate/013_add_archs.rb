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
    Architecture.find_by_name("ppc").destroy
    Architecture.find_by_name("ppc64").destroy
    Architecture.find_by_name("s390").destroy
    Architecture.find_by_name("s390x").destroy
    Architecture.find_by_name("ia64").destroy
    Architecture.find_by_name("mips").destroy
    Architecture.find_by_name("armv4l").destroy
    Architecture.find_by_name("sparc").destroy
    Architecture.find_by_name("sparc64").destroy
  end


end
