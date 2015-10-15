require 'test_helper'

class Webui::WebuiHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper
  
  def test_escape_project_list_escaped_forbidden_chars
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;/p&gt;', '&lt;p&gt;This is a paragraph&lt;/p&gt;']"
    assert escape_nested_list(input), output
  end

  def test_escape_list_escapes_forbidden_chars
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;'],['&lt;p&gt;This is a paragraph&lt;\\/p&gt;']"
    assert_equal escape_list(input), output
  end

  def test_format_projectname
    assert_equal "some:project:foo:bar", format_projectname("some:project:foo:bar", "bob")
    assert_equal "~", format_projectname("home:bob", "bob")
    assert_equal "~alice", format_projectname("home:alice", "bob")
    assert_equal "~:foo", format_projectname("home:bob:foo", "bob")
    assert_equal "~alice:foo", format_projectname("home:alice:foo", "bob")
    assert_equal "~:branch", format_projectname("home:bob:branch", "bob")
    assert_equal "~alice:branch", format_projectname("home:alice:branch", "bob")
  end
end
