require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class WebuiHelperTest < Test::Unit::TestCase

  include Webui::WebuiHelper

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
