require_relative '../test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects(:home_Iggy)
    @user = User.find_by_login('Iggy')
  end

  # spec/models/user_spec.rb
  def test_create_home_project
    User.create(login: 'moises', email: 'moises@home.com', password: '123456')
    assert Project.find_by(name: 'home:moises')
    # cleanup
    Project.find_by(name: 'home:moises').destroy

    Configuration.stubs(:allow_user_to_create_home_project).returns(false)
    User.create(login: 'bob', email: 'bob@home.com', password: '123456')
    assert_not Project.find_by(name: 'home:bob')
  end

  def test_subaccount_permission
    user = User.find_by(login: 'adrian')

    robot = User.create(login: 'robot_man', email: 'scorpions@hannover.de', password: 'dummy',
                        owner: user)

    axml = robot.render_axml
    assert_xml_tag axml, tag: :owner, attributes: { userid: 'adrian' }
    assert robot.active?

    # alias follows the user on disable
    user.state = 'locked'
    user.save!
    assert_equal false, robot.active?
  end

  def test_basics
    assert @project
    assert @user

    a = StaticPermission.new(title: 'this-one-should_go_through')
    assert a.valid?
    a.delete
  end

  def test_access
    m = Role.find_by_title('maintainer')
    assert @user.local_role?(m, @project)
    assert @user.local_role?(m, packages(:home_Iggy_TestPack))

    b = Role.find_by_title('bugowner')
    assert_not @user.local_role?(b, @project)
    assert_not @user.local_role?(m, projects(:kde4))

    user = users(:adrian)
    assert_not user.local_role?(m, @project)
    assert_not user.local_role?(m, packages(:home_Iggy_TestPack))
    assert user.local_role?(m, projects(:kde4))
    assert user.local_role?(m, packages(:kde4_kdelibs))
  end

  def test_group
    assert_not @user.in_group?('notexistent')
    assert_not @user.in_group?('test_group')
    assert users(:adrian).in_group?('test_group')
    assert_not users(:adrian).in_group?('test_group_b')
    assert_not users(:adrian).in_group?('notexistent')
  end

  def test_attribute
    obs = attrib_namespaces(:obs)
    assert_not @user.can_modify_attribute_definition?(obs)

    assert users(:king).can_modify_attribute_definition?(obs)
  end

  def test_render_axml
    axml = users(:king).render_axml
    assert_xml_tag axml, tag: :globalrole, content: 'Admin'
    axml = users(:tom).render_axml
    assert_no_xml_tag axml, tag: :globalrole, content: 'Admin'
  end

  def test_deleted_user
    assert_not_nil User.find_by_login('deleted')
    assert_raise(NotFoundError) do
      User.find_by_login!('deleted')
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
end
