class AddBugownerRole < ActiveRecord::Migration
  def self.up
    Role.create :title => 'bugowner'
  end

  def self.down
    Role.destroy :title => 'bugowner'
  end
end
