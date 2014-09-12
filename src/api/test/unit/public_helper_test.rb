require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

include PublicHelper

PublicHelper::DOWNLOAD_URL = "http://example.com/download"
YMP_URL = "http://example.com/ymp"

class PublicHelperTest < ActiveSupport::TestCase
  def test_ymp_url
    assert_equal "#{YMP_URL}/foo", ymp_url("foo")
    assert_equal "#{YMP_URL}/", ymp_url("")
  end
end

