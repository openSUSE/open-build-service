class CheckDeletedRepo < ActiveRecord::Migration
  class Repository < ActiveRecord::Base; end
  class Project < ActiveRecord::Base; end

  def self.up
    # default repository to link when original one got removed
    d = Project.where(name: 'deleted').first_or_create!
    Repository.where(db_project_id: d.id, name: 'deleted').first_or_create
  end

  def self.down
  end
end
