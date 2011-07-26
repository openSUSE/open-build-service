require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WatchedProjectTest < ActiveSupport::TestCase
  fixtures :users
  fixtures :watched_projects

  # Replace this with your real tests.
  def test_correct_class
    assert_kind_of WatchedProject, watched_projects(:first)
  end
end
