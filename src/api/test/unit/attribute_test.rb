require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class AttributeTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    @attrib_ns = AttribNamespace.find_by_name( "OBS" )
  end


  def test_namespace
    #check precondition
    assert_equal "OBS", @attrib_ns.name

    #definition is given as axml
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='fred' group='test_group' />
            </namespace>"

    xml = REXML::Document.new( axml )
    assert_equal true, AttribNamespace.create(:name => "NewNamespace").update_from_xml(xml.root)
    @ans = AttribNamespace.find_by_name( "NewNamespace" )

    #check results
    assert_not_nil @ans
    assert_equal "NewNamespace", @ans.name

    # Update a namespace with same content
    assert_equal true, @ans.update_from_xml(xml.root)
    @newans = AttribNamespace.find_by_name( "NewNamespace" )
    assert_equal @newans, @ans

    # Update a namespace with different content
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='king' />
               <modifiable_by user='fredlibs' group='test_group' />
            </namespace>"

    xml = REXML::Document.new( axml )

    assert @ans.update_from_xml(xml.root)
    @newans = AttribNamespace.find_by_name( "NewNamespace" )
    assert_equal "NewNamespace", @newans.name
  end

  def test_attrib_type
    #check precondition
    assert_equal "OBS", @attrib_ns.name

    #definition is given as axml
    axml = "<attribute name='NewAttribute'>
               <modifiable_by user='fred' group='test_group' role='maintainer' />
            </attribute>"

    xml = REXML::Document.new( axml )
    assert AttribType.create(:name => "NewAttribute", :attrib_namespace => @attrib_ns).update_from_xml(xml.root)

    @atro = @attrib_ns.attrib_types.where(:name=>"NewAttribute").first
    assert_not_nil @atro
    @at = AttribType.find_by_id( @atro.id ) # make readwritable

    #check results
    assert_not_nil @at
    assert_equal "NewAttribute", @at.name

    # Update a namespace with different content
    axml = "<attribute namespace='OBS' name='NewAttribute'>
               <modifiable_by user='king' />
               <modifiable_by user='fredlibs' group='test_group' />
               <count>67</count>
               <default>
                 <value>good</value>
                 <value>bad</value>
               </default>
               <allowed>
                 <value>good</value>
                 <value>bad</value>
                 <value>neutral</value>
               </allowed>
            </attribute>"

    xml = REXML::Document.new( axml )

    assert @at.update_from_xml(xml.root)
    assert_equal "NewAttribute", @at.name
    assert_equal "OBS", @at.attrib_namespace.name
    assert_equal 67, @at.value_count
    assert_equal 2, @at.default_values.length
    assert_equal 3, @at.allowed_values.length
    assert_equal 2, @at.attrib_type_modifiable_bies.length

    # Check if the cleanup works
    axml = "<attribute namespace='OBS' name='NewAttribute'>
               <modifiable_by user='king' />
               <default>
                 <value>good</value>
               </default>
               <allowed>
                 <value>good</value>
               </allowed>
            </attribute>"

    xml = REXML::Document.new( axml )
    assert @at.update_from_xml(xml.root)
    assert_equal "NewAttribute", @at.name
    assert_equal "OBS", @at.attrib_namespace.name
    assert_nil @at.value_count
    assert_equal 1, @at.default_values.length
    assert_equal 1, @at.allowed_values.length
    assert_equal 1, @at.attrib_type_modifiable_bies.length
    # with empty content
    axml = "<attribute namespace='OBS' name='NewAttribute' />"
    xml = REXML::Document.new( axml )
    assert @at.update_from_xml(xml.root)
    assert_equal "NewAttribute", @at.name
    assert_equal "OBS", @at.attrib_namespace.name
    assert_nil @at.value_count
    assert_equal 0, @at.default_values.length
    assert_equal 0, @at.allowed_values.length
    assert_equal 0, @at.attrib_type_modifiable_bies.length
  end

  def test_attrib
    #check precondition
    assert_equal "OBS", @attrib_ns.name

    @at = AttribType.find_by_namespace_and_name( "OBS", "Maintained" )
    assert_not_nil @at
    assert_equal 58, @at.id
    assert_equal "Maintained", @at.name
    assert_equal 0, @at.value_count
    assert_equal "OBS", @at.attrib_namespace.name

    axml = " <attribute namespace='OBS' name='Maintained' /> "
    xml = ActiveXML::Base.new( axml )

    # store in a project
    @project = DbProject.find_by_name( "kde4" )
    assert_not_nil @project
    @project.store_attribute_axml(xml)
    @project.store

    @p = DbProject.find_by_name( "kde4" )
    assert_not_nil @p
    @a = @p.find_attribute( "OBS", "Maintained" )
    assert_not_nil @a
    assert_equal "Maintained", @a.attrib_type.name


    # store in a package
    @package = DbPackage.find_by_project_and_name( "kde4", "kdebase" )
    assert_not_nil @package
    @package.store_attribute_axml(xml)
    @package.store

    @p = DbPackage.find_by_project_and_name( "kde4", "kdebase" )
    assert_not_nil @p
    @a = @p.find_attribute( "OBS", "Maintained" )
    assert_not_nil @a
    assert_equal "Maintained", @a.attrib_type.name


    # Check count validation
    axml = "<attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute> "
    xml = ActiveXML::Base.new( axml )

    # store in a project
    @project = DbProject.find_by_name( "kde4" )
    assert_not_nil @project
    assert_raise DbProject::SaveError do 
      @project.store_attribute_axml(xml)
    end
    # store in a package
    @package = DbPackage.find_by_project_and_name( "kde4", "kdebase" )
    assert_not_nil @package
    assert_raise DbPackage::SaveError do 
      @package.store_attribute_axml(xml)
    end
  end
end
