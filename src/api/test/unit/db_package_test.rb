require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class DbPackageTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @package = DbPackage.find( 10095 )
  end
  
  def test_flags_to_axml
    #check precondition
    assert_equal 1, @package.type_flags('build').size
    assert_equal 1, @package.type_flags('publish').size
    assert_equal 1, @package.type_flags('debuginfo').size
    
    xml_string = @package.to_axml

    #check the results
    xml = REXML::Document.new(xml_string)
    assert_equal 1, xml.root.get_elements("/package/build").size
    assert_equal 1, xml.root.get_elements("/package/build/*").size
    
    assert_equal 1, xml.root.get_elements("/package/publish").size
    assert_equal 1, xml.root.get_elements("/package/publish/*").size
    
    assert_equal 1, xml.root.get_elements("/package/debuginfo").size
    assert_equal 1, xml.root.get_elements("/package/debuginfo/*").size            
  end
  
  
  def test_add_new_flags_from_xml
    
    #precondition check
    @package.flags.destroy_all
    @package.reload
    assert_equal 0, @package.flags.size
    
    #package is given as axml
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
        <build>
          <enable repository='10.2' arch='i586'/>
        </build>
        <publish>
          <enable repository='10.1' arch='x86_64'/>
        </publish>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>        
        <url></url>
      </package>"
      )
    
    position = 1
    ['build', 'publish', 'debuginfo'].each do |flagtype|
      position = @package.update_flags(axml, flagtype, position)
    end
      
    @package.reload
    
    #check results
    assert_equal 1, @package.type_flags('build').size
    assert_equal 'enable', @package.type_flags('build')[0].status
    assert_equal '10.2', @package.type_flags('build')[0].repo
    assert_equal 'i586', @package.type_flags('build')[0].architecture.name
    assert_equal 1, @package.type_flags('build')[0].position
    assert_nil @package.type_flags('build')[0].db_project    
    assert_equal 'TestPack', @package.type_flags('build')[0].db_package.name
    assert_equal true, @package.enabled_for?('build', '10.2', 'i586')
    assert_equal false, @package.disabled_for?('build', '10.2', 'i586')
    
    assert_equal 1, @package.type_flags('publish').size
    assert_equal 'enable', @package.type_flags('publish')[0].status
    assert_equal '10.1', @package.type_flags('publish')[0].repo
    assert_equal 'x86_64', @package.type_flags('publish')[0].architecture.name
    assert_equal 2, @package.type_flags('publish')[0].position
    assert_nil @package.type_flags('publish')[0].db_project    
    assert_equal 'TestPack', @package.type_flags('publish')[0].db_package.name    
    
    assert_equal 1, @package.type_flags('debuginfo').size
    assert_equal 'disable', @package.type_flags('debuginfo')[0].status
    assert_equal '10.0', @package.type_flags('debuginfo')[0].repo
    assert_equal 'i586', @package.type_flags('debuginfo')[0].architecture.name
    assert_equal 3, @package.type_flags('debuginfo')[0].position
    assert_nil @package.type_flags('debuginfo')[0].db_project  
    assert_equal 'TestPack', @package.type_flags('debuginfo')[0].db_package.name        
    
  end
  
  
  def test_delete_flags_through_xml
    #check precondition
    assert_equal 1, @package.type_flags('build').size
    assert_equal 1, @package.type_flags('publish').size
    
    #package is given as axml
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
      </package>"
      )    
    
    #first update build-flags, should only delete build-flags
    @package.update_all_flags(axml)
    assert_equal 0, @package.type_flags('build').size
    assert_equal 0, @package.type_flags('publish').size
    
  end
  
  def test_rating
     # pretty silly
     assert_equal 0, @package.rating[:count]
  end
end
