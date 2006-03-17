require File.dirname(__FILE__) + '/../test_helper'

class StaticPermissionTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
  end
  
  def test_fixture_titles_should_be_correct
    fixture_permissions = [ @access_olymp_permission, @sit_on_throne_permission, 
                            @slay_monsters_permission ]
                            
    for permission in fixture_permissions
      static_permission = StaticPermission.find permission.id
      
      assert_equal permission.id, static_permission.id
      assert_equal permission.title, static_permission.title
    end
  end
  
  def test_fixture_roles_should_be_correct
    access_olymp_permission = StaticPermission.find @access_olymp_permission.id
    assert_equal 1, access_olymp_permission.roles.length
    assert_equal [@gods_role].sort {|a,b| a.id <=> b.id}, access_olymp_permission.roles.sort {|a,b| a.id <=> b.id}

    sit_on_throne_permission = StaticPermission.find @sit_on_throne_permission.id
    assert_equal 1, sit_on_throne_permission.roles.length
    assert_equal [@greek_kings_role].sort {|a,b| a.id <=> b.id}, sit_on_throne_permission.roles.sort {|a,b| a.id <=> b.id}

    slay_monsters_permission = StaticPermission.find @slay_monsters_permission.id
    assert_equal 1, slay_monsters_permission.roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, slay_monsters_permission.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_should_allow_inserting_new_permission_with_valid_data
    sit_on_throne_permission = StaticPermission.find @sit_on_throne_permission.id
    assert_equal 1, sit_on_throne_permission.all_roles.length
    assert_equal [@greek_kings_role].sort {|a,b| a.id <=> b.id}, sit_on_throne_permission.all_roles.sort {|a,b| a.id <=> b.id}

    access_olymp_permission = StaticPermission.find @access_olymp_permission.id
    assert_equal 2, access_olymp_permission.all_roles.length
    assert_equal [@gods_role, @major_gods_role].sort {|a,b| a.id <=> b.id}, access_olymp_permission.all_roles.sort {|a,b| a.id <=> b.id}

    slay_monsters_permission = StaticPermission.find @slay_monsters_permission.id
    assert_equal 1, slay_monsters_permission.all_roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, slay_monsters_permission.all_roles.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_creating_with_valid_value
    permission = StaticPermission.new
    
    permission.title = 'New permission\'s title'

    assert permission.save
    permission.reload
    
    assert_equal 'New permission\'s title', permission.title
  end

  def test_should_allow_editing_title_with_valid_value
    permission = StaticPermission.find @slay_monsters_permission.id

    permission.title = 'Brave New Title'

    assert permission.save
    permission.reload

    assert_equal 'Brave New Title', permission.title
  end
  
  def test_should_allow_destroying
    permission = StaticPermission.find @slay_monsters_permission.id
    
    assert permission.destroy
    assert permission.frozen?
    
    assert_raises(ActiveRecord::RecordNotFound) { StaticPermission.find @slay_monsters_permission.id }
  end

  def test_should_block_empty_permission_title_on_edit
    permission = StaticPermission.find @slay_monsters_permission.id
    permission.title = nil

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must be given.', permission.errors['title']
  end

  def test_should_block_too_short_permission_title_on_edit
    permission = StaticPermission.find @slay_monsters_permission.id
    permission.title = '1'

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must have more than two characters.', permission.errors['title']
  end

  def test_should_block_too_long_permission_title_on_edit
    permission = StaticPermission.find @slay_monsters_permission.id
    permission.title = 'long ' * 100

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must have less than 100 characters.', permission.errors['title']
  end

  def test_should_block_invalid_characters_in_permission_title_on_edit
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      permission = StaticPermission.find @slay_monsters_permission.id
      permission.title = "invalid char: #{char}"

      assert !permission.save

      assert_equal 1, permission.errors.count
      assert_equal "must not contain invalid characters.", permission.errors["title"]
    end
  end

  def test_should_block_non_unique_permission_title_on_edit
    permission = StaticPermission.find @slay_monsters_permission.id
    permission.title = @sit_on_throne_permission.title

    assert !permission.save
    assert_equal 1, permission.errors.count
    assert_equal "is the name of an already existing static permission.", permission.errors["title"]
  end

  def test_should_block_empty_permission_title_on_creation
    permission = StaticPermission.new
    permission.title = nil

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must be given.', permission.errors['title']
  end

  def test_should_block_too_short_permission_title_on_creation
    permission = StaticPermission.new
    permission.title = '1'

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must have more than two characters.', permission.errors['title']
  end

  def test_should_block_too_long_permission_title_on_creation
    permission = StaticPermission.new
    permission.title = 'long ' * 100

    assert !permission.save

    assert_equal 1, permission.errors.count
    assert_equal 'must have less than 100 characters.', permission.errors['title']
  end

  def test_should_block_invalid_characters_in_permission_title_on_creation
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      permission = StaticPermission.new
      permission.title = "invalid char: #{char}"

      assert !permission.save

      assert_equal 1, permission.errors.count
      assert_equal "must not contain invalid characters.", permission.errors["title"]
    end
  end

  def test_should_block_non_unique_permission_title_on_creation
    permission = StaticPermission.new
    permission.title = @sit_on_throne_permission.title

    assert !permission.save
    assert_equal 1, permission.errors.count
    assert_equal "is the name of an already existing static permission.", permission.errors["title"]
  end

  def test_should_allow_assigning_one_permission_to_one_role
    role = Role.find @greek_men_role.id
    
    permission = StaticPermission.new
    permission.title = 'My Title'
    assert permission.save
    
    permission.roles << role
    
    permission.reload
    role.reload
    
    assert_equal 1, permission.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 1, role.static_permissions.length
    assert_equal [permission].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_assigning_one_permission_to_multiple_roles
    role1 = Role.find @greek_men_role.id
    role2 = Role.find @greek_warriors_role.id

    permission = StaticPermission.new
    permission.title = 'My Title'
    assert permission.save

    permission.roles << role1 << role2

    permission.reload
    role1.reload
    role2.reload

    assert_equal 2, permission.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission.roles.sort {|a,b| a.id <=> b.id}
    
    assert_equal 1, role1.static_permissions.length
    assert_equal [permission].sort {|a,b| a.id <=> b.id}, role1.static_permissions.sort {|a,b| a.id <=> b.id}
    assert_equal 1, role2.static_permissions.length
    assert_equal [permission].sort {|a,b| a.id <=> b.id}, role2.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_assigning_multiple_permissions_to_one_role
    role = Role.find @greek_men_role.id

    permission1 = StaticPermission.new
    permission1.title = 'My Title #1'
    permission2 = StaticPermission.new
    permission2.title = 'My Title #2'
    assert permission1.save
    assert permission2.save

    permission1.roles << role
    permission2.roles << role

    permission1.reload
    permission2.reload
    role.reload

    assert_equal 1, permission1.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission1.roles.sort {|a,b| a.id <=> b.id}
    assert_equal 1, permission2.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 2, role.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_assigning_multiple_permissions_to_multiple_roles
    role1 = Role.find @greek_men_role.id
    role2 = Role.find @greek_warriors_role.id

    permission1 = StaticPermission.new
    permission1.title = 'My Title #1'
    permission2 = StaticPermission.new
    permission2.title = 'My Title #2'
    assert permission1.save
    assert permission2.save

    permission1.roles << role1 << role2
    permission2.roles << role1 << role2

    permission1.reload
    permission2.reload
    role1.reload
    role2.reload

    assert_equal 2, permission1.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission1.roles.sort {|a,b| a.id <=> b.id}
    assert_equal 2, permission2.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 2, role1.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role1.static_permissions.sort {|a,b| a.id <=> b.id}
    assert_equal 2, role2.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role2.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_deassigning_one_permission_from_one_role
    # begin copy and paste from above
    role = Role.find @greek_men_role.id

    permission1 = StaticPermission.new
    permission1.title = 'My Title #1'
    permission2 = StaticPermission.new
    permission2.title = 'My Title #2'
    assert permission1.save
    assert permission2.save

    permission1.roles << role
    permission2.roles << role

    permission1.reload
    permission2.reload
    role.reload

    assert_equal 1, permission1.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission1.roles.sort {|a,b| a.id <=> b.id}
    assert_equal 1, permission2.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 2, role.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
    # end copy and paste from above
    
    permission1.roles.delete role
    
    assert_equal 0, permission1.roles.length
    assert_equal 1, permission2.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}
  end

  def test_should_allow_deassigning_multiple_permissions_from_one_role
    # begin copy and paste from above
    role = Role.find @greek_men_role.id

    permission1 = StaticPermission.new
    permission1.title = 'My Title #1'
    permission2 = StaticPermission.new
    permission2.title = 'My Title #2'
    assert permission1.save
    assert permission2.save

    permission1.roles << role
    permission2.roles << role

    permission1.reload
    permission2.reload
    role.reload

    assert_equal 1, permission1.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission1.roles.sort {|a,b| a.id <=> b.id}
    assert_equal 1, permission2.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 2, role.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
    # end copy and paste from above

    permission1.roles.delete role
    permission2.roles.delete role

    assert_equal 0, permission1.roles.length
    assert_equal 0, permission2.roles.length
  end

  def test_should_allow_deassigning_one_permission_from_multiple_roles
    # begin copy and paste from above
    role1 = Role.find @greek_men_role.id
    role2 = Role.find @greek_warriors_role.id

    permission = StaticPermission.new
    permission.title = 'My Title'
    assert permission.save

    permission.roles << role1 << role2

    permission.reload
    role1.reload
    role2.reload

    assert_equal 2, permission.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 1, role1.static_permissions.length
    assert_equal [permission].sort {|a,b| a.id <=> b.id}, role1.static_permissions.sort {|a,b| a.id <=> b.id}
    assert_equal 1, role2.static_permissions.length
    assert_equal [permission].sort {|a,b| a.id <=> b.id}, role2.static_permissions.sort {|a,b| a.id <=> b.id}
    # end copy and paste from above
    
    permission.roles.delete role1
    permission.roles.delete role2
    
    assert_equal 0, permission.roles.length
  end

  def test_should_allow_deassigning_multiple_permissions_from_multiple_roles
    # begin copy and paste from above
    role1 = Role.find @greek_men_role.id
    role2 = Role.find @greek_warriors_role.id

    permission1 = StaticPermission.new
    permission1.title = 'My Title #1'
    permission2 = StaticPermission.new
    permission2.title = 'My Title #2'
    assert permission1.save
    assert permission2.save

    permission1.roles << role1 << role2
    permission2.roles << role1 << role2

    permission1.reload
    permission2.reload
    role1.reload
    role2.reload

    assert_equal 2, permission1.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission1.roles.sort {|a,b| a.id <=> b.id}
    assert_equal 2, permission2.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, permission2.roles.sort {|a,b| a.id <=> b.id}

    assert_equal 2, role1.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role1.static_permissions.sort {|a,b| a.id <=> b.id}
    assert_equal 2, role2.static_permissions.length
    assert_equal [permission1, permission2].sort {|a,b| a.id <=> b.id}, role2.static_permissions.sort {|a,b| a.id <=> b.id}
    # end copy and paste from above
    
    permission1.roles.delete role1
    permission1.roles.delete role2
    permission2.roles.delete role1
    permission2.roles.delete role2
    
    assert_equal 0, permission1.roles.length
    assert_equal 0, permission2.roles.length
  end
  
  def test_should_ignore_double_assigned_roles
    permission = StaticPermission.find(@slay_monsters_permission.id)
    role = Role.find @greek_heroes_role.id
    
    permission.roles << role
    
    assert_equal 1, permission.roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, permission.roles.sort {|a,b| a.id <=> b.id}
  end

  def test_permission_should_be_granted_by_role
    role = Role.find @greek_heroes_role.id
    
    assert role.static_permissions.include?(@slay_monsters_permission)
  end

  def test_permission_should_be_granted_by_role_inheritance
    role = Role.find @major_gods_role.id

    assert role.all_static_permissions.include?(@access_olymp_permission)
  end

  def test_permission_should_be_granted_by_role_through_group
    permission = StaticPermission.new
    permission.title = 'Test Permission'
    assert permission.save
    
    role = Role.new
    role.title = 'Parent Role'
    role.static_permissions << permission
    assert role.save
    
    group = Group.new
    group.title = 'Test Group'
    group.roles << role
    assert group.save
    
    assert group.all_static_permissions.include?(permission)
  end

  def test_permission_should_be_granted_by_role_inheritance_through_group
    permission = StaticPermission.new
    permission.title = 'Test Permission'
    assert permission.save

    parent_role = Role.new
    parent_role.title = 'Parent Role'
    parent_role.static_permissions << permission
    assert parent_role.save

    child_role = Role.new
    child_role.title = 'Child Role'
    parent_role.children << child_role
    assert child_role.save

    group = Group.new
    group.title = 'Test Group'
    group.roles << parent_role
    assert group.save

    assert group.all_static_permissions.include?(permission)
  end

  def test_permission_should_be_granted_by_role_through_group_inheritance
    permission = StaticPermission.new
    permission.title = 'Test Permission'
    assert permission.save

    parent_role = Role.new
    parent_role.title = 'Parent Role'
    parent_role.static_permissions << permission
    assert parent_role.save

    child_role = Role.new
    child_role.parent = parent_role
    child_role.title = 'Child Role'
    assert child_role.save

    group = Group.new
    group.title = 'Test Group'
    group.roles << child_role
    assert group.save

    assert group.all_static_permissions.include?(permission)
  end

  def test_permission_should_be_granted_by_role_inheritance_through_group_inheritance
    permission = StaticPermission.new
    permission.title = 'Test Permission'
    assert permission.save

    parent_role = Role.new
    parent_role.title = 'Parent Role'
    parent_role.static_permissions << permission
    assert parent_role.save

    child_role = Role.new
    child_role.parent = parent_role
    child_role.title = 'Child Role'
    assert child_role.save

    parent_group = Group.new
    parent_group.title = 'Parent Group'
    parent_group.roles << child_role
    assert parent_group.save

    child_group = Group.new
    child_group.title = 'Child Group'
    child_group.parent = parent_group
    assert child_group.save
    
    assert child_group.all_static_permissions.include?(permission)
  end
end
