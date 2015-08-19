class AddPpc64p7 < ActiveRecord::Migration
  def self.up
    Architecture.find_or_create_by_name "ppc64p7"
  end

  def self.down
    Architecture.find_by_name("ppc64p7").destroy
  end
end
