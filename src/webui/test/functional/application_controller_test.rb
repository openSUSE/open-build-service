require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest

  include ApplicationHelper

  def setup
  end

  def test_elide
    d = "don't shorten"
    assert_equal(d, elide(d, d.length))

    t = "Rocking the Open Build Service"
    assert_equal("...the Open Build Service", elide(t, 25, :left))
    assert_equal("R...", elide(t, 4, :right))
    assert_equal("...", elide(t, 3, :right))
    assert_equal("...", elide(t, 2, :right))
    assert_equal("Rocking t... Service", elide(t))
    assert_equal("Rock...ice", elide(t, 10))
    assert_equal("Rock...vice", elide(t, 11))
    assert_equal("Rocking...", elide(t, 10, :right))
  end

  def test_elide_two
    d = "don't shorten"
    t = "Rocking the Open Build Service"

    assert_equal([d, "Rocking the ...uild Service"], elide_two(d, t, 40))
  end

  def test_valid_xml_id
    assert_equal("_10_2", valid_xml_id("10.2"))
    assert_equal("_b", valid_xml_id("_b"))
    assert_equal("a_b", valid_xml_id("a+b"))
    assert_equal("a_b", valid_xml_id("a&b"))
    assert_equal("a_b", valid_xml_id("a:b"))
    assert_equal("a_b", valid_xml_id("a b"))
    assert_equal("a_b", valid_xml_id("a.b"))
  end

end
