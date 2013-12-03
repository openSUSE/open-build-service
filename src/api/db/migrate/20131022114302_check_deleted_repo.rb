class CheckDeletedRepo < ActiveRecord::Migration
  
  class Repository < ActiveRecord::Base; end

  def self.up
    # default repository to link when original one got removed
    d = Project.find_or_create_by_name("deleted")
    Repository.where(project_id: d.id, name: 'deleted').first_or_create
  end

  def self.down
  end
end
