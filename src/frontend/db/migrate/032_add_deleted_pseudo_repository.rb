class AddDeletedPseudoRepository < ActiveRecord::Migration
  def self.up
    DbProject.create(:name => "deleted").repositories.create(:name => "standard")
  end

  def self.down
    pro = DbProject.find_by_name("deleted")
    pro.destroy if pro
  end
end
