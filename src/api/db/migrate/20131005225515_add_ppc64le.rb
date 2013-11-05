class AddPpc64le < ActiveRecord::Migration


  def self.up
    Architecture.find_or_create_by_name "ppc64le"
  end


  def self.down
    Architecture.find_by_name("ppc64le").destroy
  end


end
