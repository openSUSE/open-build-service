require File.join File.dirname(__FILE__), '..', 'test_helper'

include ProjectHelper
include ActionView::Helpers::TagHelper

class ApplicationHelperTest < ActiveSupport::TestCase
  def test_patchinfo_rating_color
    color = ProjectHelper::patchinfo_rating_color('important')
    assert_equal 'red', color
  end

  def test_patchinfo_category_color
    color = ProjectHelper::patchinfo_category_color('security')
    assert_equal 'maroon', color
  end
end
