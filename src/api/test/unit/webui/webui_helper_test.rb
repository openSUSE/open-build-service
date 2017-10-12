require 'test_helper'

class Webui::WebuiHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper

  setup do
    @configuration = {}
    @configuration['bugzilla_url'] = 'https://bugzilla.example.org'
    @codemirror_editor_setup = 0
  end

  def test_get_frontend_url_for_with_controller # spec/helpers/webui/webui_helper_spec.rb
    url = get_frontend_url_for(controller: 'foo',
                               host: 'bar.com',
                               port: 80,
                               protocol: 'http')
    assert_equal url, 'http://bar.com:80/foo'
  end

  def test_bugzilla_url # spec/helpers/webui/webui_helper_spec.rb
    assert_not_nil bugzilla_url(['foo@example.org'], 'foobar')
  end

  def test_elide # spec/helpers/webui/webui_helper_spec.rb
    assert_empty elide('')
    assert_equal '...', elide('aaa', 3)
    assert_equal 'aaa...aaa', elide('aaaaaaaaaa', 9)
    assert_equal '...aaaaaa', elide('aaaaaaaaaa', 9, :left)
    assert_equal 'aaaaaa...', elide('aaaaaaaaaa', 9, :right)
  end

  def test_elide_two # spec/helpers/webui/webui_helper_spec.rb
    assert_equal %w[aaa bbb], elide_two('aaa', 'bbb')
  end

  def test_next_codemirror_uid
    assert_kind_of Integer, next_codemirror_uid
  end

  def test_escape_nested_list_escapes_forbidden_chars # spec/helpers/webui/webui_helper_spec.rb
    input = [['<p>home:Iggy</p>', '<p>This is a paragraph</p>'], ['<p>home:Iggy</p>', '<p>"This is a paragraph"</p>']]
    output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;This is a paragraph&lt;\\/p&gt;'],\n"
    output += "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;\\&quot;This is a paragraph\\&quot;&lt;\\/p&gt;']"

    assert_equal escape_nested_list(input), output
  end

  def test_format_projectname # spec/helpers/webui/webui_helper_spec.rb
    assert_equal "some:project:foo:bar", format_projectname("some:project:foo:bar", "bob")
    assert_equal "~", format_projectname("home:bob", "bob")
    assert_equal "~alice", format_projectname("home:alice", "bob")
    assert_equal "~:foo", format_projectname("home:bob:foo", "bob")
    assert_equal "~alice:foo", format_projectname("home:alice:foo", "bob")
    assert_equal "~:branch", format_projectname("home:bob:branch", "bob")
    assert_equal "~alice:branch", format_projectname("home:alice:branch", "bob")
  end
end
