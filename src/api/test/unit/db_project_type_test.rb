require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class DbProjectTypeTest < ActiveSupport::TestCase
  fixtures :all

  # Make sure all seed data was correctly loaded into database table
  def test_seed_data_loaded
    assert DbProjectType.find_by_name("standard")
    assert DbProjectType.find_by_name("maintenance")
    assert DbProjectType.find_by_name("maintenance_incident")
  end
end
