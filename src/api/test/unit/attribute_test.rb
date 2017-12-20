require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class AttributeTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    @attrib_ns = AttribNamespace.find_by_name('OBS')
  end

  def test_namespace
    # check precondition
    assert_equal 'OBS', @attrib_ns.name

    # definition is given as axml
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='fred' group='test_group' />
            </namespace>"

    xml = Xmlhash.parse(axml)
    assert_equal true, AttribNamespace.create(name: 'NewNamespace').update_from_xml(xml)
    @ans = AttribNamespace.find_by_name('NewNamespace')

    # check results
    assert_not_nil @ans
    assert_equal 'NewNamespace', @ans.name

    # Update a namespace with same content
    assert_equal true, @ans.update_from_xml(xml)
    @newans = AttribNamespace.find_by_name('NewNamespace')
    assert_equal @newans, @ans

    # Update a namespace with different content
    axml = "<namespace name='NewNamespace'>
               <modifiable_by user='king' />
               <modifiable_by user='fredlibs' group='test_group' />
            </namespace>"

    xml = Xmlhash.parse(axml)

    assert @ans.update_from_xml(xml)
    @newans = AttribNamespace.find_by_name('NewNamespace')
    assert_equal 'NewNamespace', @newans.name
  end

  def test_attrib_type
    # check precondition
    assert_equal 'OBS', @attrib_ns.name

    # definition is given as axml
    axml = "<attribute name='NewAttribute'>
               <modifiable_by user='fred' group='test_group' role='maintainer' />
            </attribute>"

    xml = Xmlhash.parse(axml)
    assert AttribType.create(name: 'NewAttribute', attrib_namespace: @attrib_ns).update_from_xml(xml)

    @atro = @attrib_ns.attrib_types.where(name: 'NewAttribute').first
    assert_not_nil @atro
    @at = AttribType.find_by_id(@atro.id) # make readwritable

    # check results
    assert_not_nil @at
    assert_equal 'NewAttribute', @at.name

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

    xml = Xmlhash.parse(axml)

    assert @at.update_from_xml(xml)
    assert_equal 'NewAttribute', @at.name
    assert_equal 'OBS', @at.attrib_namespace.name
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

    xml = Xmlhash.parse(axml)
    assert @at.update_from_xml(xml)
    assert_equal 'NewAttribute', @at.name
    assert_equal 'OBS', @at.attrib_namespace.name
    assert_nil @at.value_count
    assert_equal 1, @at.default_values.length
    assert_equal 1, @at.allowed_values.length
    assert_equal 1, @at.attrib_type_modifiable_bies.length
    # with empty content
    axml = "<attribute namespace='OBS' name='NewAttribute' />"
    xml = Xmlhash.parse(axml)
    assert @at.update_from_xml(xml)
    assert_equal 'NewAttribute', @at.name
    assert_equal 'OBS', @at.attrib_namespace.name
    assert_nil @at.value_count
    assert_equal 0, @at.default_values.length
    assert_equal 0, @at.allowed_values.length
    assert_equal 0, @at.attrib_type_modifiable_bies.length
  end

  def test_attrib
    User.current = users(:king)

    # check precondition
    assert_equal 'OBS', @attrib_ns.name

    @at = AttribType.find_by_namespace_and_name('OBS', 'Maintained')
    assert_not_nil @at
    assert_equal 58, @at.id
    assert_equal 'Maintained', @at.name
    assert_equal 0, @at.value_count
    assert_equal 'OBS', @at.attrib_namespace.name

    axml = " <attribute namespace='OBS' name='Maintained' /> "
    xml = ActiveXML::Node.new(axml)

    # store in a project
    @project = Project.create(name: 'GNOME18')
    assert_not_nil @project
    @project.store_attribute_axml(xml)
    @project.store

    @p = Project.find_by_name('GNOME18')
    assert_not_nil @p
    @a = @p.find_attribute('OBS', 'Maintained')
    assert_not_nil @a
    assert_equal 'Maintained', @a.attrib_type.name

    # store in a package
    @package = @project.packages.create(name: 'kdebase')
    assert_not_nil @package
    @package.store_attribute_axml(xml)
    @package.store

    @p = Package.find_by_project_and_name('GNOME18', 'kdebase')
    assert_not_nil @p
    @a = @p.find_attribute('OBS', 'Maintained')
    assert_not_nil @a
    assert_equal 'Maintained', @a.attrib_type.name

    # Check count validation
    axml = "<attribute namespace='OBS' name='Maintained' >
              <value>blah</value>
            </attribute> "
    xml = ActiveXML::Node.new(axml)

    # store in a project
    @project = Project.find_by_name('GNOME18')
    assert_not_nil @project
    assert_raise ActiveRecord::RecordInvalid do
      @project.store_attribute_axml(xml)
    end
    # store in a package
    @package = Package.find_by_project_and_name('GNOME18', 'kdebase')
    assert_not_nil @package
    e = assert_raise(ActiveRecord::RecordInvalid) do
      @package.store_attribute_axml(xml)
    end
    assert_match %r{Values has 1 values, but only 0 are allowed}, e.message

    User.current = nil
  end
end
