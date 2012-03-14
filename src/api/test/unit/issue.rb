require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class IssueTest < ActiveSupport::TestCase
  fixtures :users
  fixtures :db_packages
  fixtures :issue_trackers

  def test_create_and_destroy
    #pkg = DbPackage.find( 10095 )
    iggy = User.find_by_email("Iggy@pop.org")
    bnc = IssueTracker.find_by_name("bnc")
    issue = Issue.create :name => '0815', :issue_tracker => bnc
    issue.save
    issue.summary = 'This unit test is not working'
    issue.state = 'INVALID'
    issue.owner = iggy
    issue.save
    issue.destroy
  end
  
end
