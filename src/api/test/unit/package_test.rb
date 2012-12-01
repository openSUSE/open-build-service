require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'faker'

class PackageTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @package = Package.find( 10095 )
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
    axml = Xmlhash.parse(
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
    
    @package.save
    @package.reload
    
    #check results
    assert_equal 1, @package.type_flags('build').size
    assert_equal 'enable', @package.type_flags('build')[0].status
    assert_equal '10.2', @package.type_flags('build')[0].repo
    assert_equal 'i586', @package.type_flags('build')[0].architecture.name
    assert_equal 1, @package.type_flags('build')[0].position
    assert_nil @package.type_flags('build')[0].project
    assert_equal 'TestPack', @package.type_flags('build')[0].package.name
    assert_equal true, @package.enabled_for?('build', '10.2', 'i586')
    assert_equal false, @package.disabled_for?('build', '10.2', 'i586')
    
    assert_equal 1, @package.type_flags('publish').size
    assert_equal 'enable', @package.type_flags('publish')[0].status
    assert_equal '10.1', @package.type_flags('publish')[0].repo
    assert_equal 'x86_64', @package.type_flags('publish')[0].architecture.name
    assert_equal 2, @package.type_flags('publish')[0].position
    assert_nil @package.type_flags('publish')[0].project    
    assert_equal 'TestPack', @package.type_flags('publish')[0].package.name    
    
    assert_equal 1, @package.type_flags('debuginfo').size
    assert_equal 'disable', @package.type_flags('debuginfo')[0].status
    assert_equal '10.0', @package.type_flags('debuginfo')[0].repo
    assert_equal 'i586', @package.type_flags('debuginfo')[0].architecture.name
    assert_equal 3, @package.type_flags('debuginfo')[0].position
    assert_nil @package.type_flags('debuginfo')[0].project
    assert_equal 'TestPack', @package.type_flags('debuginfo')[0].package.name        
    
  end
  
  
  def test_delete_flags_through_xml
    #check precondition
    assert_equal 1, @package.type_flags('build').size
    assert_equal 1, @package.type_flags('publish').size
    
    #package is given as axml
    axml = Xmlhash.parse(
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

  def test_render
     xml = packages(:kdelibs).render_axml
     assert_equal Xmlhash.parse(xml), {"name"=>"kdelibs", 
	     "project"=>"kde4", "title"=>"blub", "description"=>"blub", 
	     "devel"=>{"project"=>"home:coolo:test", "package"=>"kdelibs_DEVEL_package"}, 
	     "person"=>[{"userid"=>"fredlibs", "role"=>"maintainer"}, {"userid"=>"adrian", "role"=>"reviewer"}], "group"=>{"groupid"=>"test_group", "role"=>"maintainer"}}
  end

  def test_can_be_deleted
    assert !packages(:kdelibs).can_be_deleted?
  end

  def test_store
    orig = Xmlhash.parse(@package.to_axml)

    assert_raise Package::SaveError do
      @package.update_from_xml(Xmlhash.parse(
        "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
        <devel project='Notexistant'/>
      </package>"))
    end
    assert_raise Package::SaveError do
      @package.update_from_xml(Xmlhash.parse(
        "<package name='TestPack' project='home:Iggy'>
	   <title>My Test package</title>
	   <description></description>
	   <devel project='home:Iggy' package='nothing'/>
        </package>"))
    end

    assert_raise ActiveRecord::RecordNotFound do
     @package.update_from_xml(Xmlhash.parse(
       "<package name='TestBack' project='home:Iggy'>
           <title>My Test package</title>
           <description></description>
	   <person userid='alice' role='maintainer'/>
        </package>"))
    end

    assert_raise Package::SaveError do
      @package.update_from_xml(Xmlhash.parse(
         "<package name='TestBack' project='home:Iggy'>
                              <title>My Test package</title>
                              <description></description>
			      <person userid='tom' role='coolman'/>
                            </package>"))
    end

    assert_equal orig, Xmlhash.parse(@package.to_axml)
    assert @package.update_from_xml(Xmlhash.parse(
      "<package name='TestPack' project='home:Iggy'>
        <title>My Test package</title>
        <description></description>
        <person userid='fred' role='bugowner'/>
        <person userid='Iggy' role='maintainer'/>
      </package>"))
  end

  def test_add_user
    orig = @package.to_axml
    @package.add_user('tom', 'maintainer')
    @package.update_from_xml(Xmlhash.parse(orig))

    assert_raise Package::SaveError do
      @package.add_user('tom', 'Admin')
    end
    assert_equal orig, @package.to_axml
  end

  test "names are case sensitive" do
    np = @package.project.packages.new(name: 'testpack')
    xh = Xmlhash.parse(@package.to_axml)
    np.update_from_xml(xh)
    assert_equal np.name, 'testpack'
    assert np.id > 0
    assert np.id != @package.id
  end

  test "invalid names are catched" do
    @package.name = '_coolproject'
    assert !@package.save
    assert_raise(ActiveRecord::RecordInvalid) do
      @package.save!
    end
    @package.name = Faker::Lorem.characters(255)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      @package.save!
    end
    assert_match %r{Name is too long}, e.message
    @package.name = '_product'
    assert @package.valid?
    @package.name = '.product'
    assert !@package.valid?
    @package.name = 'product.i586'
    assert @package.valid?
  end

end
