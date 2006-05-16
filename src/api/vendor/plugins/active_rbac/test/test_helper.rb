# =============================================================================
# Include the files required to test Engines.

# Load the default rails test helper - this will load the environment.
require File.dirname(__FILE__) + '/../../../../test/test_helper'

# ensure that the Engines testing enhancements are loaded and will override Rails own
# code where needed. This line is very important!
require File.join(Engines.config(:root), "engines", "lib", "engines", "testing_extensions")

# set up the fixtures location to use your engine's fixtures
Test::Unit::TestCase.fixture_path = File.dirname(__FILE__)  + "/fixtures/"
$LOAD_PATH.unshift(Test::Unit::TestCase.fixture_path)
# =============================================================================

# Tweak the TestCase class to our liking.
class Test::Unit::TestCase
  # Turn these on to use transactional fixtures with table_name(:fixture_name) instantiation of fixtures
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = true

  # Add more helper methods to be used by all tests here...
end