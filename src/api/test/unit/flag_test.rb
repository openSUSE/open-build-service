require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class FlagTest < ActiveSupport::TestCase
  fixtures :all

  def test_validation
    # only a flag with a set project_id OR package_id can be saved!
    f = Flag.new(project: projects(:home_Iggy), package: packages(:home_Iggy_TestPack), flag: 'build', status: 'enable')

    # the flag shouldn't be saved
    assert_equal false, f.save

    # expected error message
    assert_equal "Please set either project or package", f.errors[:name].join
  end

  def test_to_xml_error
    # if no flagstatus set, an error should be raised!
    f = Flag.new(project: projects(:home_Iggy), architecture: architectures(:i586), repo: '999.999')
    f.flag = 'build'
    assert_equal false, f.save
    f.status = 'enabled'
    assert_equal false, f.save
    f.status = 'enable'
    assert_equal true, f.save

    f = Flag.find_by_repo("999.999")
    assert_kind_of Flag, f

    builder = Nokogiri::XML::Builder.new
    f.to_xml(builder)
    assert_xml_tag builder.to_xml, tag: "enable", attributes: { repository: "999.999", arch: "i586" }
  end
end
