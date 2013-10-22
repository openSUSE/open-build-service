class CheckDeletedRepo < ActiveRecord::Migration
  def self.up
    # default repository to link when original one got removed
    d = Project.find_or_create_by_name("deleted")
    if d.repositories.find_by_name("deleted").nil?
      d.repositories.create name: "deleted"
    end
  end

  def self.down
  end
end
