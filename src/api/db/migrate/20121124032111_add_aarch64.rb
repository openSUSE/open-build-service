class AddAarch64 < ActiveRecord::Migration


  def self.up
    Architecture.where(name: "aarch64").first_or_create
  end


  def self.down
    Architecture.find_by_name("aarch64").destroy
  end


end
