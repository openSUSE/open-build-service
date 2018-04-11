# frozen_string_literal: true

require_relative '../test_helper'

class AttribPolicyTest < ActiveSupport::TestCase
  fixtures :all

  test 'admin can crud attrib' do
    user = users(:Admin)
    policy = AttribPolicy.new(user, Attrib.new)
    assert policy.create?, "#{user} can't CRUD attrib"
  end

  test 'role can crud attrib_type' do
    attrib = attribs(:quality_category_apache2_package)
    # Fred is maintainer
    policy = AttribPolicy.new(users(:fred), attrib)
    assert policy.create?, "#{users(:fred)} can't CRUD attrib_type"
    # Iggy not
    policy = AttribPolicy.new(users(:Iggy), attrib)
    assert_not policy.create?, "#{users(:Iggy)} shouldn't be able to CRUD attrib_type"
  end

  test 'group can crud attrib_type' do
    attrib = attribs(:maintained_apache2_package)
    # maintenance_coord is in the group maint_coord
    policy = AttribPolicy.new(users(:maintenance_coord), attrib)
    assert policy.create?, "#{users(:maintenance_coord)} can't CRUD attrib_type"
    # Iggy not
    policy = AttribPolicy.new(users(:Iggy), attrib)
    assert_not policy.create?, "#{users(:Iggy)} shouldn't be able to CURD attrib_type"
  end

  test 'user can crud attrib_type' do
    attrib = Attrib.new(attrib_type_id: 56, project: Project.find_by(name: 'Apache'))
    # Fred is explicitely set
    policy = AttribPolicy.new(users(:fred), attrib)
    assert policy.create?, "#{users(:fred)} can't CRUD attrib_type"
    # Iggy not
    policy = AttribPolicy.new(users(:Iggy), attrib)
    assert_not policy.create?, "#{users(:Iggy)} shouldn't be able to CURD attrib_type"
  end

  # AttribNamespaceModifiableBy
  test 'group can crud attrib_namespace' do
    # user6 is in group honks
    policy = AttribNamespacePolicy.new(users(:user6), attrib_namespaces(:obs))
    assert policy.create?, "#{users(:user6)} can't CRUD attrib_namespace"
    # Iggy is not
    policy = AttribNamespacePolicy.new(users(:Iggy), attrib_namespaces(:obs))
    assert_not policy.create?, "#{users(:Iggy)} shouldn't be able to CURD attrib_namespace"
  end

  test 'user can crud attrib_namespace' do
    # Fred is explicitely set
    policy = AttribNamespacePolicy.new(users(:fred), attrib_namespaces(:obs))
    assert policy.create?, "#{users(:fred)} can't CRUD attrib_namespace"
    # Iggy not
    policy = AttribNamespacePolicy.new(users(:Iggy), attrib_namespaces(:obs))
    assert_not policy.create?, "#{users(:Iggy)} shouldn't be able to CURD attrib_namespace"
  end
end
