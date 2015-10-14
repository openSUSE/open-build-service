require 'test_helper'

class Webui::WebuiHelperTest < ActiveSupport::TestCase
  include Webui::WebuiHelper

  setup do
    @configuration = {}
    @configuration['bugzilla_url'] = 'https://bugzilla.example.org'
    @codemirror_editor_setup = 0
  end

  def test_get_frontend_url_for_with_controller
    url = get_frontend_url_for(controller: 'foo',
                               host: 'bar.com',
                               port: 80,
                               protocol: 'http')
    assert_equal url, 'http://bar.com:80/foo'
  end

  def test_bugzilla_url
    assert_not_nil bugzilla_url(['foo@example.org'], 'foobar')
  end

  def test_plural
    assert_equal 'car',  plural(1, 'car', ' cars')
    assert_equal 'cars', plural(5, 'car', 'cars')
  end

  def test_valid_xml_id
    assert_equal '_123_456', valid_xml_id('123 456')
  end

  def test_elide
    assert_empty elide('')
    assert_equal '...', elide('aaa', 3)
    assert_equal 'aaa...aaa', elide('aaaaaaaaaa', 9)
    assert_equal '...aaaaaa', elide('aaaaaaaaaa', 9, :left)
    assert_equal 'aaaaaa...', elide('aaaaaaaaaa', 9, :right)
  end

  def test_elide_two
    assert_equal ["aaa", "bbb"], elide_two('aaa', 'bbb')
  end

  def test_next_codemirror_uid
    assert_kind_of Fixnum, next_codemirror_uid
  end

  def test_array_cachekey
    assert_not_nil array_cachekey([1, 2, 3])
  end

  def test_escape_project_list_escaped_forbidden_chars
    input = ['<p>home:Iggy</p>', '<p>This is a paragraph</p>']
    output = "['&lt;p&gt;home:Iggy&lt;/p&gt;', '&lt;p&gt;This is a paragraph&lt;/p&gt;']"
    assert escape_nested_list(input), output
  end
end
