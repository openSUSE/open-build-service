require File.join File.dirname(__FILE__), '..', 'test_helper'

include ProjectHelper
include ActionView::Helpers::TagHelper

class ProjectHelperTest < ActiveSupport::TestCase
  def test_patchinfo_rating_color
    color = ProjectHelper::patchinfo_rating_color('important')
    color.must_equal 'red'
  end

  def test_patchinfo_category_color
    color = ProjectHelper::patchinfo_category_color('security')
    color.must_equal 'maroon'
  end
end
