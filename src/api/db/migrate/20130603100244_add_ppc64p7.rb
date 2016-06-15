class AddPpc64p7 < ActiveRecord::Migration
  def self.up
    Architecture.where(name: "ppc64p7").first_or_create
  end

  def self.down
    Architecture.find_by_name("ppc64p7").destroy
  end
end
