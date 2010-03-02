class AddReviewerRole < ActiveRecord::Migration
  def self.up
    reviewer = Role.create :title => 'reviewer'
  end

  def self.down
    Role.find_by_title('reviewer').destroy
  end
end
