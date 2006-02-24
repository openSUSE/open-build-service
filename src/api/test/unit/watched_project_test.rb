require File.dirname(__FILE__) + '/../test_helper'

class WatchedProjectTest < Test::Unit::TestCase
  fixtures :users
  fixtures :watched_projects

  # Replace this with your real tests.
  def test_truth
    assert_kind_of WatchedProject, watched_projects(:first)
  end
end
