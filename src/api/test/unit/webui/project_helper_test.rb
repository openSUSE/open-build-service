require 'test_helper'

class Webui::ProjectHelperTest < ActiveSupport::TestCase
  include Webui::ProjectHelper

  def test_patchinfo_rating_color # spec/helpers/webui/project_helper_spec.rb
    color = patchinfo_rating_color('important')
    assert_equal 'red', color
  end

  def test_patchinfo_category_color # spec/helpers/webui/project_helper_spec.rb
    color = patchinfo_category_color('security')
    assert_equal 'maroon', color
  end

  def test_request_state_icon # spec/helpers/webui/project_helper_spec.rb
    assert_equal map_request_state_to_flag('new'), 'flag_green'
    assert_equal map_request_state_to_flag(nil), ''
  end

  def test_escape_list_escapes_forbidden_chars # spec/helpers/webui/project_helper_spec.rb
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;'],['&lt;p&gt;This is a paragraph&lt;\\/p&gt;']"
    assert_equal escape_list(input), output
  end
end
