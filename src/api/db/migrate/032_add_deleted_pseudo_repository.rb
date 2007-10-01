class AddDeletedPseudoRepository < ActiveRecord::Migration
  def self.up
    DbProject.create(:name => "deleted").repositories.create(:name => "standard")
  end

  def self.down
    DbProject.find_by_name("deleted").destroy
  end
end
