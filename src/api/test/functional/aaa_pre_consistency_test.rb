require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_consistency_helper"

class AAAPreConsistency < ActionDispatch::IntegrationTest
  fixtures :all

  def test_resubmit_fixtures
    login_king
    wait_for_scheduler_start

    compare_project_and_package_lists

    resubmit_all_fixtures
  end
end
