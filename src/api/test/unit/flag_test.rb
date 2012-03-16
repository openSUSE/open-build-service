require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class FlagTest < ActiveSupport::TestCase
  fixtures :flags


  def test_validation
      #only a flag wirh a set project_id OR package_id can be saved!
      f = Flag.new(:db_project_id => 502, :db_package_id => 10095, :flag => 'build')
      
      #the flag shouldn't be saved
      assert_equal  false, f.save
      
      #expected error message
      assert_equal "Please set either project_id or package_id.", f.errors[:name].join
  end
  
  
  def test_to_xml_error
    #if no flagstatus set, an error should be raised!
    f = Flag.new(:db_project_id => 502, :architecture_id => 1, :repo => '999.999')
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
    generated_xml = ActiveXML::Base.new(builder.to_xml)
    # there is no guarantee on the order
    assert_equal generated_xml.element_name, 'enable'
    assert_equal generated_xml.value(:repository), "999.999"
    assert_equal generated_xml.value(:arch), "i586"
  end
  
end
