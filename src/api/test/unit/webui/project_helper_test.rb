require 'test_helper'

class Webui::ProjectHelperTest < ActiveSupport::TestCase
  include Webui::ProjectHelper

  def test_patchinfo_rating_color
    color = patchinfo_rating_color('important')
    color.must_equal 'red'
  end

  def test_patchinfo_category_color
    color = patchinfo_category_color('security')
    color.must_equal 'maroon'
  end

  def test_request_state_icon
    map_request_state_to_flag('new').must_equal 'flag_green'
    map_request_state_to_flag(nil).must_equal ''
  end

end
