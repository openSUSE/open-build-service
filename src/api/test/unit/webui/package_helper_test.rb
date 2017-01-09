require 'test_helper'

class Webui::PackageHelperTest < ActiveSupport::TestCase
  include Webui::PackageHelper

  def test_nbsp # spec/helpers/webui/package_helper_spec.rb
    assert nbsp("a").is_a?(ActiveSupport::SafeBuffer)

    sanitized_string = nbsp("<b>unsafe<b/>")
    assert_equal "&lt;b&gt;unsafe&lt;b/&gt;", sanitized_string
    assert sanitized_string.is_a?(ActiveSupport::SafeBuffer)

    sanitized_string = nbsp("my file")
    assert_equal "my&nbsp;file", sanitized_string
    assert sanitized_string.is_a?(ActiveSupport::SafeBuffer)

    long_file_name = "a" * 50 + "b" * 50 + "c" * 10
    sanitized_string = nbsp(long_file_name)
    assert_equal long_file_name.scan(/.{1,50}/).join("<wbr>"), sanitized_string
    assert sanitized_string.is_a?(ActiveSupport::SafeBuffer)
  end
end
