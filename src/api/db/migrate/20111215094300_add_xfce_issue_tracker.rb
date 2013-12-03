class AddXfceIssueTracker < ActiveRecord::Migration
  def self.up
    IssueTracker.find_or_create_by_name('bxo', :description => 'XFCE Bugzilla', :kind => 'bugzilla', :regex => 'bxo#(\d+)', :url => 'https://bugzilla.xfce.org/', :show_url => 'https://bugzilla.xfce.org/show_bug.cgi?id=@@@')
    IssueTracker.write_to_backend
  end

  def self.down
    it = IssueTracker.find_by_name('bxo')
    it.destroy if it
    IssueTracker.write_to_backend
  end
end
