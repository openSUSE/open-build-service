# frozen_string_literal: true
require_relative '../test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects(:home_Iggy)
    @user = User.find_by_login('Iggy')
  end

  def test_create_home_project # spec/models/user_spec.rb
    User.create(login: 'moises', email: 'moises@home.com', password: '123456')
    assert Project.find_by(name: 'home:moises')
    # cleanup
    Project.find_by(name: 'home:moises').destroy

    Configuration.stubs(:allow_user_to_create_home_project).returns(false)
    User.create(login: 'bob', email: 'bob@home.com', password: '123456')
    assert !Project.find_by(name: 'home:bob')
  end

  def test_can_modify_project
    user = User.find_by(login: 'adrian')
    project = Project.find_by(name: 'home:adrian')

    assert user.can_modify_project?(project)

    assert_raise ArgumentError, 'illegal parameter type to User#can_modify_project?: Package' do
      user.can_modify_project?(Package.last)
    end
  end

  def test_subaccount_permission
    user = User.find_by(login: 'adrian')

    robot = User.create(login: 'robot_man', email: 'scorpions@hannover.de', password: 'dummy',
                        owner: user)

    axml = robot.render_axml
    assert_xml_tag axml, tag: :owner, attributes: { userid: 'adrian' }
    assert robot.is_active?

    # alias follows the user on disable
    user.state = 'locked'
    user.save!
    assert_equal false, robot.is_active?
  end

  def test_basics
    assert @project
    assert @user

    a = StaticPermission.new title: 'this-one-should_go_through'
    assert a.valid?
    a.delete
  end

  def test_access
    assert @user.has_local_permission? 'change_project', @project
    assert @user.has_local_permission? 'change_package', packages(:home_Iggy_TestPack)

    m = Role.find_by_title('maintainer')
    assert @user.has_local_role?(m, @project)
    assert @user.has_local_role?(m, packages(:home_Iggy_TestPack))

    b = Role.find_by_title 'bugowner'
    assert !@user.has_local_role?(b, @project)
    assert !@user.has_local_role?(m, projects(:kde4))

    user = users(:adrian)
    assert !user.has_local_role?(m, @project)
    assert !user.has_local_role?(m, packages(:home_Iggy_TestPack))
    assert user.has_local_role?(m, projects(:kde4))
    assert user.has_local_role?(m, packages(:kde4_kdelibs))

    tom = users(:tom)
    assert !tom.has_local_permission?('change_project', projects(:kde4))
    assert !tom.has_local_permission?('change_package', packages(:kde4_kdelibs))
  end

  def test_group
    assert !@user.is_in_group?('notexistant')
    assert !@user.is_in_group?('test_group')
    assert users(:adrian).is_in_group?('test_group')
    assert !users(:adrian).is_in_group?('test_group_b')
    assert !users(:adrian).is_in_group?('notexistant')
  end

  def test_attribute
    obs = attrib_namespaces(:obs)
    assert !@user.can_modify_attribute_definition?(obs)

    assert users(:king).can_modify_attribute_definition?(obs)
  end

  def test_render_axml
    axml = users(:king).render_axml
    assert_xml_tag axml, tag: :globalrole, content: 'Admin'
    axml = users(:tom).render_axml
    assert_no_xml_tag axml, tag: :globalrole, content: 'Admin'
  end

  def test_deleted_user
    assert_not_nil User.find_by_login 'deleted'
    assert_raise NotFoundError do
      User.find_by_login! 'deleted'
    end
  end

  def test_user_requests
    assert_equal 0, users(:user4).tasks
    assert_equal 1, users(:tom).tasks
    assert_equal 3, users(:adrian).tasks
    assert_equal 4, users(:fred).tasks
  end

  def test_update_globalroles
    user = User.find_by(login: 'tom')
    user.roles << Role.create(title: 'local_role', global: false)
    user.roles << Role.create(title: 'global_role_1', global: true)
    global_role2 = Role.create(title: 'global_role_2', global: true)
    user.roles << global_role2

    user.update_globalroles([global_role2, Role.global.where(title: 'Admin').first])

    updated_roles = user.reload.roles.map(&:title)
    assert updated_roles.include?('global_role_2')
    assert updated_roles.include?('Admin')
    assert updated_roles.include?('local_role'), 'Should keep local roles'
    assert_equal 3, user.roles.count, 'Should remove all additional global roles'
    assert_equal 3, user.roles_users.count
  end

  test 'gravatar image' do
    f = Configuration.first
    f.gravatar = true
    f.save # of course just for this test

    stub_request(:get, 'http://www.gravatar.com/avatar/ef677ecd5e63faa5842d43bcdfca2f33?d=wavatar&s=20').
      to_return(status: 200, body: 'Superpng', headers: {})
    assert_equal 'Superpng', users(:tom).gravatar_image(20)

    stub_request(:get, 'http://www.gravatar.com/avatar/ef677ecd5e63faa5842d43bcdfca2f33?d=wavatar&s=200').to_timeout
    assert_equal :none, users(:tom).gravatar_image(200)
  end
end
