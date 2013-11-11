class AddPpc64le < ActiveRecord::Migration


  def self.up
    Architecture.where(name: "ppc64le").first_or_create
  end


  def self.down
    Architecture.find_by_name("ppc64le").destroy
  end


end
