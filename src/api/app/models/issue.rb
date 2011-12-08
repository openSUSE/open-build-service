class Issue < ActiveRecord::Base
  has_many :db_package_issues, :foreign_key => 'issue_id', :dependent => :destroy
  has_one :user, :foreign_key => 'owner_id'
  belongs_to :issue_tracker

  DEFAULT_RENDER_PARAMS = {:except => :id, :except => :issue_tracker_id, :skip_types => true, :include => :issue_tracker }
end
