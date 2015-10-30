require 'test_helper'

class Webui::WebuiHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper
  
  def test_escape_project_list_escaped_forbidden_chars
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;/p&gt;', '&lt;p&gt;This is a paragraph&lt;/p&gt;']"
    assert escape_nested_list(input), output
  end
end
