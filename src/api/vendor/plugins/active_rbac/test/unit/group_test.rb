require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles
  
  def setup
  end
  
  #
  # The tests
  #
  
  def test_groups_from_fixtures_should_be_correct
    fixture_groups = [ @heroes_group, @greeks_group, @cretes_group,
                       @greek_heroes_group, @greek_kings_group, @gods_group,
                       @gods_not_in_olymp_group, @greek_warriors_group,
                       @troys_besiegers_group, @punished_heroes_group ]

    for fixture_group in fixture_groups do
      queried_group = Group.find fixture_group.id
      
      assert_kind_of Group, queried_group

      assert_equal queried_group.id, fixture_group.id
      assert_equal queried_group.parent, fixture_group.parent
      assert_equal queried_group.created_at, fixture_group.created_at
      assert_equal queried_group.updated_at, fixture_group.updated_at
      assert_equal queried_group.title, fixture_group.title
    end
  end
  
  def test_users_on_fixture_groups_should_be_correct
    group = Group.find @greek_heroes_group.id
    assert_equal 1, group.users.length
    assert_equal [@perseus_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    group = Group.find @gods_not_in_olymp_group.id
    assert_equal 1, group.users.length
    assert_equal [@hades_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    group = Group.find @troys_besiegers_group.id
    assert_equal 1, group.users.length
    assert_equal [@agamemnon_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    group = Group.find @punished_heroes_group.id
    assert_equal 1, group.users.length
    assert_equal [@odysseus_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    group = Group.find @cretes_group.id
    assert_equal 1, group.users.length
    assert_equal [@ariadne_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    group = Group.find @greek_kings_group.id
    assert_equal 1, group.users.length
    assert_equal [@minos_user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}

    no_user_groups = [ @heroes_group, @greeks_group, @gods_group,
                       @greek_warriors_group ]

    for no_user_group in no_user_groups do
      queried_group = Group.find no_user_group.id

      assert_equal 0, queried_group.users.length
    end
  end

  def test_all_users_on_fixture_groups_should_be_correct
    group = Group.find @greek_heroes_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@perseus_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @gods_not_in_olymp_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@hades_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @troys_besiegers_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@agamemnon_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @punished_heroes_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@odysseus_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @cretes_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@ariadne_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @greek_kings_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@minos_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @gods_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@hades_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @greeks_group.id
    assert_equal 2, group.all_users.length
    assert_equal [@ariadne_user, @minos_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    group = Group.find @greek_warriors_group.id
    assert_equal 1, group.all_users.length
    assert_equal [@agamemnon_user].sort {|a,b| a.id <=> b.id}, group.all_users.sort {|a,b| a.id <=> b.id}

    no_all_user_groups = [ @heroes_group ]

    for no_user_group in no_all_user_groups do
      queried_group = Group.find no_user_group.id

      assert_equal 0, queried_group.all_users.length
    end
  end

  def test_roles_on_fixture_groups_should_be_correct
    group = Group.find @greek_heroes_group.id
    assert_equal 1, group.roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @gods_not_in_olymp_group.id
    assert_equal 1, group.roles.length
    assert_equal [@god_of_death_role].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @troys_besiegers_group.id
    assert_equal 1, group.roles.length
    assert_equal [@greek_warriors_role].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @greek_kings_group.id
    assert_equal 1, group.roles.length
    assert_equal [@greek_kings_role].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}

    no_roles_groups = [ @heroes_group, @gods_group, @greek_warriors_group,
                           @punished_heroes_group, @greeks_group, @cretes_group]

    for no_role_group in no_roles_groups do
      queried_group = Group.find no_role_group.id

      assert_equal 0, queried_group.roles.length
    end
  end

  def test_all_roles_on_fixture_groups_should_be_correct
    group = Group.find @greek_heroes_group.id
    assert_equal 1, group.all_roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, group.all_roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @gods_not_in_olymp_group.id
    assert_equal 1, group.all_roles.length
    assert_equal [@god_of_death_role].sort {|a,b| a.id <=> b.id}, group.all_roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @troys_besiegers_group.id
    assert_equal 2, group.all_roles.length
    assert_equal [@greek_warriors_role, @greeks_role].sort {|a,b| a.id <=> b.id}, group.all_roles.sort {|a,b| a.id <=> b.id}

    group = Group.find @greek_kings_group.id
    assert_equal 2, group.all_roles.length
    assert_equal [@greek_kings_role, @greek_men_role].sort {|a,b| a.id <=> b.id}, group.all_roles.sort {|a,b| a.id <=> b.id}

    no_all_roles_groups = [ @heroes_group, @gods_group, @greek_warriors_group,
                           @punished_heroes_group, @greeks_group, @cretes_group]

    for no_all_roles_group in no_all_roles_groups do
      queried_group = Group.find no_all_roles_group.id

      assert_equal 0, queried_group.roles.length
    end
  end

  def test_changing_fixture_groups_title_to_valid_value_should_work
    group = Group.find @heroes_group.id
    group.title = 'New Group Title'
    
    assert group.save
    group.reload
    
    assert_equal 'New Group Title', group.title
  end
  
  def test_changing_fixture_groups_parent_to_nil_should_work
    group = Group.find @greek_kings_group.id
    group.parent = nil

    assert group.save
    group.reload

    assert_nil group.parent
  end
  
  def test_changing_fixture_groups_parent_to_valid_group_should_work
    group = Group.find @greek_kings_group.id
    group.parent = Group.find(@greek_heroes_group.id)

    assert group.save
    group.reload

    assert_equal Group.find(@greek_heroes_group.id), group.parent
  end

  def test_creating_group_without_parent_should_work
    group = Group.new
    group.title = 'Valid Group Title'
    
    assert group.save
    group.reload
    
    assert_equal 'Valid Group Title', group.title
  end
  
  def test_creating_group_with_parent_should_work
    group = Group.new
    group.title = 'Valid Group Title'
    group.parent = Group.find(@greek_heroes_group.id)

    assert group.save
    group.reload

    assert_equal 'Valid Group Title', group.title
    assert_equal Group.find(@greek_heroes_group.id), group.parent
  end
  
  def test_assigning_one_role_to_group_should_work
    # @hero_group is a good dummy because it has no roles, user, parents
    group = Group.find @heroes_group.id
    role = Role.find @greek_heroes_role.id
    
    group.roles << role
    
    assert group.save
    group.reload
    
    assert_equal 1, group.roles.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_deassigning_one_role_from_group_should_work
    # @hero_group is a good dummy because it has no roles, user, parents
    group = Group.find @gods_not_in_olymp_group.id
    role = Role.find @god_of_death_role.id

    group.roles.delete role

    assert group.save
    group.reload

    assert_equal 0, group.roles.length
  end
  
  def test_assigning_multiple_roles_to_group_should_work
    # @hero_group is a good dummy because it has no roles, user, parents
    group = Group.find @heroes_group.id
    role1 = Role.find @greek_heroes_role.id
    role2 = Role.find @greek_kings_role.id

    group.roles << role1 << role2

    assert group.save
    group.reload

    assert_equal 2, group.roles.length
    assert_equal [role1, role2].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_deassigning_multiple_roles_from_group_should_work
    test_assigning_multiple_roles_to_group_should_work
    
    group = Group.find @heroes_group.id
    role1 = Role.find @greek_heroes_role.id
    role2 = Role.find @greek_kings_role.id

    group.roles.delete role1
    group.roles.delete role2
    
    assert_equal 0, group.roles.length
  end
  
  def test_deassigning_all_roles_from_group_should_work
    test_assigning_multiple_roles_to_group_should_work

    group = Group.find @heroes_group.id

    group.roles.clear

    assert_equal 0, group.roles.length
  end
  
  def test_assigning_one_group_to_one_user_should_work
    group = Group.find @heroes_group.id
    user = User.find @odysseus_user.id
    
    group.users << user
    assert group.save
    group.reload
    
    assert_equal 1, group.users.length
    assert_equal [user].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}
  end
  
  def test_assigning_one_group_to_multiple_users_should_work
    group = Group.find @heroes_group.id
    user1 = User.find @odysseus_user.id
    user2 = User.find @perseus_user.id

    group.users << user1 << user2
    assert group.save
    group.reload

    assert_equal 2, group.users.length
    assert_equal [user1, user2].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}
  end
  
  def test_deassigning_multiple_users_from_one_group_should_work
    test_assigning_one_group_to_one_user_should_work
    
    group = Group.find @heroes_group.id
    user = User.find @odysseus_user.id
    
    group.users.delete user

    assert group.save
    group.reload

    assert_equal 0, group.users.length
  end

  def test_deassigning_one_user_from_one_group_should_work
    test_assigning_one_group_to_multiple_users_should_work
    
    group = Group.find @heroes_group.id
    user1 = User.find @odysseus_user.id
    user2 = User.find @perseus_user.id
    
    group.users.delete user1
    group.users.delete user2
    
    assert group.save
    group.reload

    assert_equal 0, group.users.length
  end

  def test_deassigning_all_users_from_one_group_should_work
    test_assigning_one_group_to_multiple_users_should_work

    group = Group.find @heroes_group.id
    
    group.users.clear
    
    assert group.save
    group.reload

    assert_equal 0, group.users.length
  end

  def test_should_inherit_one_role_from_parent_group
    # add role
    greeks = Group.find@greeks_group.id
    greeks.roles << Role.find(@greeks_role.id)
    assert greeks.save
    
    cretes = Group.find @cretes_group.id
    assert_equal 0, cretes.roles.length
    assert_equal 1, cretes.all_roles.length
    assert_equal [@greeks_role].sort {|a,b| a.id <=> b.id}, cretes.all_roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_should_inherit_multiple_roles_from_parent_group
    # add roles
    greeks = Group.find @greeks_group.id
    greeks.roles << Role.find(@greeks_role.id) << Role.find(@greek_heroes_role.id)
    assert greeks.save

    cretes = Group.find @cretes_group.id
    assert_equal 0, cretes.roles.length
    assert_equal 2, cretes.all_roles.length
    assert_equal [@greeks_role, @greek_heroes_role].sort {|a,b| a.id <=> b.id}, cretes.all_roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_destroy_on_group_without_parent_should_work
    heroes = Group.find @heroes_group.id
    assert heroes.destroy
    
    assert heroes.frozen?
    assert_raise(ActiveRecord::RecordNotFound) { Group.find @heroes_group.id }
  end

  def test_destroy_on_group_with_parent_should_work
    cretes = Group.find @cretes_group.id
    assert cretes.destroy

    assert cretes.frozen?
    assert_raise(ActiveRecord::RecordNotFound) { Group.find @cretes_group.id }
  end

  def test_should_block_empty_group_title_on_creation
    group = Group.new

    assert !group.save
    
    assert_equal 1, group.errors.count
    assert_equal 'must have more than two characters.', group.errors['title']
  end

  def test_should_block_too_short_group_title_on_creation
    group = Group.new
    group.title = '1'

    assert !group.save

    assert_equal 1, group.errors.count
    assert_equal 'must have more than two characters.', group.errors['title']
  end

  def test_should_block_too_long_group_title_on_creation
    group = Group.new
    group.title = 'long ' * 100

    assert !group.save

    assert_equal 1, group.errors.count
    assert_equal 'must have less than 100 characters.', group.errors['title']
  end

  def test_should_block_invalid_characters_in_group_title_on_creation
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      group = Group.new
      group.title = "invalid char: #{char}"

      assert !group.save

      assert_equal 1, group.errors.count
      assert_equal "must not contain invalid characters.", group.errors["title"]
    end
  end

  def test_should_block_non_unique_group_title_on_creation
    group = Group.new
    group.title = @gods_role.title

    assert !group.save
    assert_equal 1, group.errors.count
    assert_equal "is the name of an already existing group.", group.errors["title"]
  end

  def test_should_block_empty_group_title_on_edit
    group = Group.find @greek_heroes_group.id
    group.title = nil

    assert !group.save

    assert_equal 1, group.errors.count, 'Fails because of an error in RoR. See http://dev.rubyonrails.org/ticket/2022 for details.'
    assert_equal 'must have more than two characters.', group.errors['title']
  end

  def test_should_block_too_short_group_title_on_edit
    group = Group.find @greek_heroes_group.id
    group.title = '1'

    assert !group.save

    assert_equal 1, group.errors.count
    assert_equal 'must have more than two characters.', group.errors['title']
  end

  def test_should_block_too_long_group_title_on_edit
    group = Group.find @greek_heroes_group.id
    group.title = 'long ' * 100

    assert !group.save

    assert_equal 1, group.errors.count
    assert_equal 'must have less than 100 characters.', group.errors['title']
  end

  def test_should_block_invalid_characters_in_group_title_on_edit
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      group = Group.find @greek_heroes_group.id
      group.title = "invalid char: #{char}"

      assert !group.save

      assert_equal 1, group.errors.count
      assert_equal "must not contain invalid characters.", group.errors["title"]
    end
  end

  def test_should_block_non_unique_group_title_on_edit
    group = Group.find @gods_group.id
    group.title = @greek_heroes_group.title

    assert !group.save
    assert_equal 1, group.errors.count
    assert_equal "is the name of an already existing group.", group.errors["title"]
  end

  # No counterpart for edit since it can only happen with existing groups.
  def test_should_block_recursion_in_tree
    group = Group.find @greeks_group.id

    assert_raises(RecursionInTree) { group.parent = Group.find @cretes_group.id }
  end

  def test_should_block_destroy_group_with_children
    group = Group.find @greeks_group.id
    assert_raises(CantDeleteWithChildren) { group.destroy }
  end

  def test_descendants_and_self_should_work_with_one_child
    group = Group.find @gods_group.id

    assert_equal 2, group.descendants_and_self.length
    assert_equal [@gods_group, @gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, group.descendants_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_descendants_and_self_should_work_with_multiple_children_in_one_level
    group = Group.find @greeks_group.id
    assert_equal 3, group.descendants_and_self.length
    assert_equal [@greeks_group, @cretes_group, @greek_kings_group].sort {|a,b| a.id <=> b.id}, group.descendants_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_ancestors_and_self_should_work_with_no_ancestor
    group = Group.find @gods_group.id

    assert_equal 1, group.ancestors_and_self.length
    assert_equal [group].sort {|a,b| a.id <=> b.id}, group.ancestors_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_ancestors_and_self_should_work_with_one_ancestor
    group = Group.find @gods_not_in_olymp_group.id

    assert_equal 2, group.ancestors_and_self.length
    assert_equal [group, @gods_group].sort {|a,b| a.id <=> b.id}, group.ancestors_and_self.sort {|a,b| a.id <=> b.id}
  end
end