require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_consistency_helper"

class AAAPreConsistency < ActionDispatch::IntegrationTest
  fixtures :all

  def test_resubmit_fixtures
    login_king
    wait_for_scheduler_start

    consistency_check

    resubmit_all_fixtures

    consistency_check
  end
end
