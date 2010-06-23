require File.dirname(__FILE__) + '/../test_helper'

class DbPackageTest < ActiveSupport::TestCase
  fixtures :db_projects, :db_packages, :repositories, :flags, :users

  def setup
    @package = DbPackage.find( 10095 )
  end
  
    
  def test_flags_to_axml
    #check precondition
    assert_equal 1, @package.build_flags.size
    assert_equal 1, @package.publish_flags.size
    assert_equal 1, @package.debuginfo_flags.size
    
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
      "<package name='TestPack' project='home:tscholz'>
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
    
    ['build', 'publish', 'debuginfo'].each do |flagtype|
      @package.update_flags(axml, flagtype)
    end
      
    @package.reload
    
    #check results
    assert_equal 1, @package.build_flags.size
    assert_equal 'enable', @package.build_flags[0].status
    assert_equal '10.2', @package.build_flags[0].repo
    assert_equal 'i586', @package.build_flags[0].architecture.name
    assert_equal 0, @package.build_flags[0].position
    assert_nil @package.build_flags[0].db_project    
    assert_equal 'TestPack', @package.build_flags[0].db_package.name
    
    assert_equal 1, @package.publish_flags.size
    assert_equal 'enable', @package.publish_flags[0].status
    assert_equal '10.1', @package.publish_flags[0].repo
    assert_equal 'x86_64', @package.publish_flags[0].architecture.name
    assert_equal 0, @package.publish_flags[0].position
    assert_nil @package.publish_flags[0].db_project    
    assert_equal 'TestPack', @package.publish_flags[0].db_package.name    
    
    assert_equal 1, @package.debuginfo_flags.size
    assert_equal 'disable', @package.debuginfo_flags[0].status
    assert_equal '10.0', @package.debuginfo_flags[0].repo
    assert_equal 'i586', @package.debuginfo_flags[0].architecture.name
    assert_equal 0, @package.debuginfo_flags[0].position
    assert_nil @package.debuginfo_flags[0].db_project  
    assert_equal 'TestPack', @package.debuginfo_flags[0].db_package.name        
    
  end
  
  
  def test_delete_flags_through_xml
    #check precondition
    assert_equal 1, @package.build_flags.size
    assert_equal 1, @package.publish_flags.size
    
    #package is given as axml
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:tscholz'>
        <title>My Test package</title>
        <description></description>
      </package>"
      )    
    
    #first update build-flags, should only delete build-flags
    @package.update_flags(axml, 'build')
    assert_equal 0, @package.build_flags.size
        
    #second update publish-flags, should delete publish-flags    
    @package.update_flags(axml, 'publish')
    assert_equal 0, @package.publish_flags.size
    
  end
  
  
  def test_store_axml
    #package is given as axml
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:tscholz'>
        <title>My Test package</title>
        <description></description>
        <debuginfo>
          <disable repository='10.0' arch='i586'/>
        </debuginfo>    
        <url></url>
      </package>"
      )
      
    Suse::Backend.put( '/source/home:tscholz/_meta', DbProject.find_by_name('home:tscholz').to_axml)
    Suse::Backend.put( '/source/home:tscholz/TestPack/_meta', DbPackage.find_by_name('TestPack').to_axml)

    @package.store_axml(axml)
    
    assert_equal 0, @package.build_flags.size
    assert_equal 1, @package.debuginfo_flags.size        
  end
    
end
