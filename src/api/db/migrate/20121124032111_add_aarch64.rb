class AddAarch64 < ActiveRecord::Migration


  def self.up
    Architecture.find_or_create_by_name "aarch64"
  end


  def self.down
    Architecture.find_by_name("aarch64").destroy
  end


end
