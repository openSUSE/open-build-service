class AddBugownerRole < ActiveRecord::Migration
  def self.up
    Role.create(:title => 'bugowner') unless Role.find_by_title('bugowner')
  end

  def self.down
    Role.destroy :title => 'bugowner'
  end
end
