require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_consistency_helper"

class AAAPreConsistency < ActionDispatch::IntegrationTest
  fixtures :all

  def test_resubmit_fixtures
    resubmit_all_fixtures
  end
end

