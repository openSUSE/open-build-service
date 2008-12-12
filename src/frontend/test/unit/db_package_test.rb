require File.dirname(__FILE__) + '/../test_helper'

class DbPackageTest < Test::Unit::TestCase
  fixtures :db_projects, :db_packages, :repositories, :flags, :users

  def setup
    @package = DbPackage.find( 10095 )
  end
  
    
  def test_flags_to_axml
    #check precondition
    assert_equal 1, @package.build_flags.size
    assert_equal 1, @package.publish_flags.size
    assert_equal 1, @package.debug_flags.size
    
    xml_string = @package.to_axml

    #check the results
    xml = REXML::Document.new(xml_string)
    assert_equal 1, xml.root.get_elements("/package/build").size
    assert_equal 1, xml.root.get_elements("/package/build/*").size
    
    assert_equal 1, xml.root.get_elements("/package/publish").size
    assert_equal 1, xml.root.get_elements("/package/publish/*").size
    
    assert_equal 1, xml.root.get_elements("/package/debug").size
    assert_equal 1, xml.root.get_elements("/package/debug/*").size            
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
          <enabled repository='10.2' arch='i386'/>
        </build>
        <publish>
          <enabled repository='10.1' arch='x86_64'/>
        </publish>
        <debug>
          <disabled repository='10.0' arch='i386'/>
        </debug>        
        <url></url>
      </package>"
      )
    
    ['build', 'publish', 'debug'].each do |flagtype|
      @package.update_flags(:package => axml, :flagtype => flagtype)
    end
      
    @package.reload
    
    #check results
    assert_equal 1, @package.build_flags.size
    assert_equal 'enabled', @package.build_flags[0].status
    assert_equal '10.2', @package.build_flags[0].repo
    assert_equal 'i386', @package.build_flags[0].architecture.name
    assert_equal 1, @package.build_flags[0].position
    assert_nil @package.build_flags[0].db_project    
    assert_equal 'TestPack', @package.build_flags[0].db_package.name
    
    assert_equal 1, @package.publish_flags.size
    assert_equal 'enabled', @package.publish_flags[0].status
    assert_equal '10.1', @package.publish_flags[0].repo
    assert_equal 'x86_64', @package.publish_flags[0].architecture.name
    assert_equal 1, @package.publish_flags[0].position
    assert_nil @package.publish_flags[0].db_project    
    assert_equal 'TestPack', @package.publish_flags[0].db_package.name    
    
    assert_equal 1, @package.debug_flags.size
    assert_equal 'disabled', @package.debug_flags[0].status
    assert_equal '10.0', @package.debug_flags[0].repo
    assert_equal 'i386', @package.debug_flags[0].architecture.name
    assert_equal 1, @package.debug_flags[0].position
    assert_nil @package.debug_flags[0].db_project  
    assert_equal 'TestPack', @package.debug_flags[0].db_package.name        
    
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
    @package.update_flags(:package => axml, :flagtype => 'build')
    assert_equal 0, @package.build_flags.size
        
    #second update publish-flags, should delete publish-flags    
    @package.update_flags(:package => axml, :flagtype => 'publish')
    assert_equal 0, @package.publish_flags.size
    
  end
  
  
  def test_flag_type_mismatch
    #check precondition
    assert_equal 1, @package.build_flags.size    
  
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:tscholz'>
        <title>My Test package</title>
        <description></description>
        <build>
          <enabled repository='10.2' arch='i386'/>
        </build>      
        <url></url>
        <disable repository='10.0' arch='i386'/>
      </package>"
      )    
  
    assert_raise(RuntimeError){
      @package.flag_compatibility_check(:package => axml)
      }
    
    assert_equal 1, @package.build_flags.size  
  end
  
  
  def test_old_flag_to_build_flag
    #check precondition
    assert_equal 1, @package.build_flags.size    

    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:tscholz'>
        <title>My Test package</title>
        <description></description>    
        <url></url>
        <disable/>
        <disable repository='10.2'/>
        <disable repository='10.2' arch='i386'/>
      </package>"
      )      
      
    @package.old_flag_to_build_flag(:package => axml, :flagtype => 'build')
    assert_equal 3, @package.build_flags.size  
  end
  
  
  def test_store_axml
    #package is given as axml
    axml = ActiveXML::Base.new(
      "<package name='TestPack' project='home:tscholz'>
        <title>My Test package</title>
        <description></description>
        <debug>
          <disabled repository='10.0' arch='i386'/>
        </debug>    
        <url></url>
        <disable/>
      </package>"
      )
      
    @package.store_axml(axml)
    
    assert_equal 1, @package.build_flags.size
    assert_equal 1, @package.debug_flags.size        
  end
    
end
