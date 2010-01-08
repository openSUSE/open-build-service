require File.dirname(__FILE__) + '/../test_helper'

class AttributeTest < ActiveSupport::TestCase
  fixtures :attribs, :attrib_namespaces, :attrib_namespace_modifiable_bies, :attrib_types
  fixtures :groups, :users

  def setup
    @attrib_ns = AttribNamespace.find_by_name( "NSTEST" )
  end


  def test_namespace
    #check precondition
    assert_equal "NSTEST", @attrib_ns.name

    #package is given as axml
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='fred' group='test_group' />
            </namespace>"

    xml = REXML::Document.new( axml )
    xml_element = xml.elements["/namespace"] if xml
    assert_equal true, AttribNamespace.create(:name => "NewNamespace").update_from_xml(xml_element)
    @ans = AttribNamespace.find_by_name( "NewNamespace" )

    #check results
    assert_not_nil @ans
    assert_equal "NewNamespace", @ans.name

    # Update a namespace with same content
    assert_equal true, @ans.update_from_xml(xml_element)
    @newans = AttribNamespace.find_by_name( "NewNamespace" )
    assert_equal @newans, @ans

    # Update a namespace with different content
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='king' />
               <modifiable_by user='fredlibs' group='test_group' />
            </namespace>"

    xml = REXML::Document.new( axml )
    xml_element = xml.elements["/namespace"] if xml

    assert_equal true, @ans.update_from_xml(xml_element)
    @newans = AttribNamespace.find_by_name( "NewNamespace" )
    assert_equal "NewNamespace", @newans.name
  end

end
