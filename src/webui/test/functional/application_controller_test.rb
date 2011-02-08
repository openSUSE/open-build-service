require File.dirname(__FILE__) + '/../test_helper'

class ApplicationControllerTest < ActionController::IntegrationTest

  def setup
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
