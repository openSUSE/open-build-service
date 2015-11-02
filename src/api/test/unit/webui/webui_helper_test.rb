require 'test_helper'

class Webui::WebuiHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper

  def test_escape_nested_list_escapes_forbidden_chars
    input = [['<p>home:Iggy</p>', '<p>This is a paragraph</p>'], ['<p>home:Iggy</p>', '<p>"This is a paragraph"</p>']]
    output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;This is a paragraph&lt;\\/p&gt;'],\n"
    output += "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;\\&quot;This is a paragraph\\&quot;&lt;\\/p&gt;']"

    assert_equal escape_nested_list(input), output
  end

  def test_escape_list_escapes_forbidden_chars
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;'],['&lt;p&gt;This is a paragraph&lt;\\/p&gt;']"
    assert_equal escape_list(input), output
  end
end
