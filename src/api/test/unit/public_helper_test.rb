require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

include PublicHelper

PublicHelper::DOWNLOAD_URL = "http://example.com/download"
CONFIG['ymp_url'] = "http://example.com/ymp"

class PublicHelperTest < ActiveSupport::TestCase
  def test_download_url
    assert_equal "#{PublicHelper::DOWNLOAD_URL}/foo", download_url("foo")
    assert_equal "#{PublicHelper::DOWNLOAD_URL}/", download_url("")
  end

  def test_ymp_url
    assert_equal "#{CONFIG['ymp_url']}/foo", ymp_url("foo")
    assert_equal "#{CONFIG['ymp_url']}/", ymp_url("")
  end
end

