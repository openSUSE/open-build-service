# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class AttribTest < ActiveSupport::TestCase
  fixtures :all

  setup do
    @namespace = AttribNamespace.find_by name: 'OBS'
  end

  test 'should have an attrib_type' do
    attrib = Attrib.new
    assert_not attrib.valid?
    assert_equal ["can't be blank"], attrib.errors.messages[:attrib_type]
  end

  test 'should have one object' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribOneObject')
    attrib = Attrib.new(attrib_type: attrib_type)
    # No object is invalid
    assert_not attrib.valid?
    assert_equal ["can't be blank"], attrib.errors.messages[:package]
    assert_equal ["can't be blank"], attrib.errors.messages[:project]
    # Project is valid
    attrib.project = Project.first
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    # Package is valid
    attrib.project = nil
    attrib.package = Package.first
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    # Package AND Project is invalid
    attrib.project = Project.first
    attrib.package = Package.first
    assert_not attrib.valid?
    assert_equal ["can't also be present"], attrib.errors.messages[:package_id]
  end

  test 'should have no values' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValueCount0')
    attrib_value = AttribValue.new(value: 'xxx')
    attrib = Attrib.new(attrib_type: attrib_type, package: Package.first)

    attrib_type.value_count = 0
    attrib.values << attrib_value
    assert_not attrib.valid?
    assert_equal ['has 1 values, but only 0 are allowed'], attrib.errors.messages[:values]
  end

  test 'should have one value' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValueCount1')
    attrib_value = AttribValue.new(value: 'xxx')
    attrib_value_second = AttribValue.new(value: 'yyy')
    attrib = Attrib.new(attrib_type: attrib_type, package: Package.first)

    attrib_type.value_count = 1
    attrib.values << attrib_value
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    attrib.values << attrib_value_second
    assert_not attrib.valid?
    assert_equal ['has 2 values, but only 1 are allowed'], attrib.errors.messages[:values]
    attrib.values.delete_all
    assert_not attrib.valid?
    assert_equal ['has 0 values, but only 1 are allowed'], attrib.errors.messages[:values]
  end

  test 'can have any number of values' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValueCountNil')
    attrib = Attrib.new(attrib_type: attrib_type, package: Package.first)

    # nil
    attrib_type.value_count = nil
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    # one
    attrib.values << AttribValue.new(value: 'xxx')
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    # two
    attrib.values << AttribValue.new(value: 'xxx')
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
  end

  test 'sets values from default_values' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribDefaultValues')
    attrib = Attrib.new(attrib_type: attrib_type, package: Package.first)
    # default value position 1
    attrib_type.default_values << AttribDefaultValue.new(value: 'xxx', position: 1)
    attrib_type.save
    attrib.values.build(attrib: attrib, position: 1)
    assert_equal 'xxx', attrib.values[0].value
    # default value position 2
    attrib_type.default_values << AttribDefaultValue.new(value: 'yyy', position: 2)
    attrib_type.save
    attrib.values.build(attrib: attrib, position: 2)
    assert_equal 'yyy', attrib.values[1].value
  end

  test 'validates allowed_values' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribAllowedValues')
    attrib_type.allowed_values << AttribAllowedValue.new(value: 'One')
    attrib_type.allowed_values << AttribAllowedValue.new(value: 'Two')
    attrib_type.allowed_values << AttribAllowedValue.new(value: 'Three')

    attrib = Attrib.new(attrib_type: attrib_type, package: Package.first)
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"

    attrib.values.new(value: 'xxx')
    assert_not attrib.valid?
    assert_equal ["Value 'xxx' is not allowed. Please use one of: One, Two, Three"], attrib.errors.messages[:values]

    attrib.values.delete_all
    attrib.values.new(value: 'Three')
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
  end

  test 'sets values from default_values and validates allowed_values and value_count' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValueCombi')
    attrib_type.allowed_values << AttribAllowedValue.new(value: 'One')
    attrib_type.allowed_values << AttribAllowedValue.new(value: 'Two')
    attrib_type.default_values << AttribDefaultValue.new(value: 'One', position: 1)
    attrib_type.value_count = 1
    attrib_type.save
    attrib = Attrib.new(attrib_type: attrib_type, project: Project.first)

    attrib.values.build(attrib: attrib, position: 1)
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
    assert_equal 'One', attrib.values.first.value
  end

  test 'should have no issues' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribIssues')
    attrib = Attrib.new(attrib_type: attrib_type, project: Project.first)

    attrib.issues << Issue.new(name: '12345')
    assert_not attrib.valid?
    assert_equal ["can't have issues"], attrib.errors.messages[:issues]
    attrib_type.issue_list = true
    assert attrib.valid?, "attrib should be valid: #{attrib.errors.messages}"
  end

  test 'find_by_container_and_fullname' do
    project = Project.find_by name: 'BaseDistro2.0'
    attrib = Attrib.find_by_container_and_fullname(project, 'OBS:UpdateProject')
    assert_equal 103, attrib.id
  end

  test 'should show full name' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribFullname')
    attrib = Attrib.new(attrib_type: attrib_type, project: Project.first)

    assert_equal 'OBS:AttribFullname', attrib.fullname
  end

  test 'should return container' do
    project = Project.find_by name: 'BaseDistro2.0'
    attrib = Attrib.find_by_container_and_fullname(project, 'OBS:UpdateProject')
    assert_equal 103, attrib.id
    assert_equal project, attrib.project

    package = Package.get_by_project_and_name('Apache', 'apache2', use_source: false)
    attrib = Attrib.find_by_container_and_fullname(package, 'OBS:Maintained')
    assert_equal 101, attrib.id
    assert_equal package, attrib.package
  end

  test 'values_editable' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValuesEditable')
    attrib = Attrib.new(attrib_type: attrib_type, project: Project.first)
    # value_count == nil
    assert attrib.values_editable?
    # value_count > 0
    attrib_type.value_count = 1
    assert attrib.values_editable?
    attrib_type.value_count = nil
    # issue list is open
    attrib_type.issue_list = true
    assert attrib.values_editable?
    attrib_type.issue_list = false
    # value_count = 0
    attrib_type.value_count = 0
    assert_not attrib.values_editable?
  end

  test 'values_removeable values_addable' do
    attrib_type = AttribType.new(attrib_namespace: @namespace, name: 'AttribValuesEditable')
    attrib = Attrib.new(attrib_type: attrib_type, project: Project.first)

    # If unlimited values
    assert attrib.values_addable?
    # If value_count != values.length
    attrib_type.value_count = 1
    assert attrib.values_addable?
  end
end
