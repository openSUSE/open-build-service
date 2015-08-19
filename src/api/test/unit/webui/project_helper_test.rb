require 'test_helper'

include Webui::ProjectHelper

class Webui::ProjectHelperTest < ActiveSupport::TestCase
  def test_patchinfo_rating_color
    color = Webui::ProjectHelper::patchinfo_rating_color('important')
    color.must_equal 'red'
  end

  def test_patchinfo_category_color
    color = Webui::ProjectHelper::patchinfo_category_color('security')
    color.must_equal 'maroon'
  end
end
