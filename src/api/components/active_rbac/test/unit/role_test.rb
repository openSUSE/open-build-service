require File.dirname(__FILE__) + '/../test_helper'

class RoleTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles

  def setup
  end

  #
  # The tests
  #

  def test_roles_from_fixtures_should_be_correct
    fixture_roles = [ @gods_role, @major_gods_role, @greek_heroes_role,
                      @greek_men_role, @greek_kings_role, @god_of_death_role,
                      @greeks_role, @greek_warriors_role ]

    for fixture_role in fixture_roles do
      queried_role = Role.find fixture_role.id

      assert_equal queried_role.id, fixture_role.id
      assert_equal queried_role.parent, fixture_role.parent
      assert_equal queried_role.created_at, fixture_role.created_at
      assert_equal queried_role.updated_at, fixture_role.updated_at
      assert_equal queried_role.title, fixture_role.title
    end
  end
  
  def test_users_on_fixture_roles_should_work
    role = Role.find @gods_role.id
    assert_equal 1, role.users.length
    assert_equal [@hermes_user].sort {|a,b| a.id <=> b.id}, role.users.sort {|a,b| a.id <=> b.id}

    role = Role.find @major_gods_role.id
    assert_equal 1, role.users.length
    assert_equal [@zeus_user].sort {|a,b| a.id <=> b.id}, role.users.sort {|a,b| a.id <=> b.id}

    no_users_roles = [ @greek_heroes_role, @greek_men_role, @greek_kings_role, 
                       @god_of_death_role, @greeks_role, @greek_warriors_role ]
    no_users_roles.each do |r|
      role = Role.find r.id
      assert_equal 0, role.users.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, role.users.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_all_users_on_fixture_roles_should_work
    role = Role.find @gods_role.id
    assert_equal 2, role.all_users.length
    assert_equal [@hermes_user, @zeus_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @major_gods_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@zeus_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_heroes_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@perseus_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @god_of_death_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@hades_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_kings_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@minos_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_warriors_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@agamemnon_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_men_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@minos_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}

    role = Role.find @greeks_role.id
    assert_equal 1, role.all_users.length
    assert_equal [@agamemnon_user].sort {|a,b| a.id <=> b.id}, role.all_users.sort {|a,b| a.id <=> b.id}
  end

  def test_groups_on_fixture_roles_should_work
    role = Role.find @greek_heroes_role.id
    assert_equal 1, role.groups.length
    assert_equal [@greek_heroes_group].sort {|a,b| a.id <=> b.id}, role.groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @god_of_death_role.id
    assert_equal 1, role.groups.length
    assert_equal [@gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, role.groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_kings_role.id
    assert_equal 1, role.groups.length
    assert_equal [@greek_kings_group].sort {|a,b| a.id <=> b.id}, role.groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_warriors_role.id
    assert_equal 1, role.groups.length
    assert_equal [@troys_besiegers_group].sort {|a,b| a.id <=> b.id}, role.groups.sort {|a,b| a.id <=> b.id}

    no_groups_roles = [ @gods_role, @major_gods_role, @greek_men_role, @greeks_role ]
    no_groups_roles.each do |r|
      role = Role.find r.id
      assert_equal 0, role.groups.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, role.groups.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_all_groups_on_fixture_roles_should_work
    role = Role.find @greek_heroes_role.id
    assert_equal 1, role.all_groups.length
    assert_equal [@greek_heroes_group].sort {|a,b| a.id <=> b.id}, role.all_groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @god_of_death_role.id
    assert_equal 1, role.all_groups.length
    assert_equal [@gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, role.all_groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_kings_role.id
    assert_equal 1, role.all_groups.length
    assert_equal [@greek_kings_group].sort {|a,b| a.id <=> b.id}, role.all_groups.sort {|a,b| a.id <=> b.id}

    role = Role.find @greek_warriors_role.id
    assert_equal 1, role.all_groups.length
    assert_equal [@troys_besiegers_group].sort {|a,b| a.id <=> b.id}, role.all_groups.sort {|a,b| a.id <=> b.id}

    no_all_groups_roles = [ @gods_role, @major_gods_role, @greek_men_role, @greeks_role ]
    no_all_groups_roles.each do |r|
      role = Role.find r.id
      assert_equal 0, role.all_groups.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, role.all_groups.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_allow_changing_fixtures_roles_title_to_valid_value_should_work
    role = Role.find @god_of_death_role.id
    role.title = 'Nice Role Title'
    
    assert role.save
    role.reload
    
    assert_equal 'Nice Role Title', role.title
  end

  def test_changing_fixtures_roles_parent_to_nil_should_work
    role = Role.find @major_gods_role.id
    role.parent = nil

    assert role.save
    role.reload

    assert_nil role.parent
  end

  def test_changing_fixtures_roles_parent_to_valid_role_should_work
    role = Role.find @major_gods_role.id
    role.parent = Role.find @god_of_death_role.id

    assert role.save
    role.reload

    assert_equal Role.find(@god_of_death_role.id), role.parent
  end

  def test_creating_role_without_parent_should_work
    role = Role.new
    role.title = 'Nice New Role'
    
    assert role.save
    role.reload
    
    assert_equal 'Nice New Role', role.title
    assert_nil role.parent
  end

  def test_creating_role_with_parent_should_work
    role = Role.new
    role.title = 'Nice New Role'
    role.parent = Role.find @major_gods_role.id

    assert role.save
    role.reload

    assert_equal 'Nice New Role', role.title
    assert_equal Role.find(@major_gods_role.id), role.parent
  end

  def test_destroy_on_role_without_parent_should_work
    role = Role.find @god_of_death_role.id
    assert role.destroy
    
    assert_raise(ActiveRecord::RecordNotFound) { Role.find @god_of_death_role.id }
  end

  def test_destroy_on_role_with_parent_should_work
    role = Role.find @major_gods_role.id
    assert role.destroy

    assert_raise(ActiveRecord::RecordNotFound) { Role.find @major_gods_role.id }
    
    role = Role.find @gods_role.id
    assert_equal 0, role.children.length
  end

  def test_should_block_empty_role_title_on_creation
    role = Role.new
    role.title == nil
    
    assert !role.save
    
    assert_equal 1, role.errors.count
    assert_equal 'must have more than two characters.', role.errors['title']
  end

  def test_should_block_too_short_role_title_on_creation
    role = Role.new
    role.title = '1'

    assert !role.save

    assert_equal 1, role.errors.count
    assert_equal 'must have more than two characters.', role.errors['title']
  end

  def test_should_block_too_long_role_title_on_creation
    role = Role.new
    role.title = 'long ' * 100

    assert !role.save

    assert_equal 1, role.errors.count
    assert_equal 'must have less than 100 characters.', role.errors['title']
  end

  def test_should_block_invalid_characters_in_role_title_on_creation
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      role = Role.new
      role.title = "invalid char: #{char}"

      assert !role.save

      assert_equal 1, role.errors.count
      assert_equal "must not contain invalid characters.", role.errors["title"]
    end
  end

  def test_should_block_non_unique_role_title_on_creation
    role = Role.new
    role.title = @major_gods_role.title
    
    assert !role.save
    assert_equal 1, role.errors.count
    assert_equal "is the name of an already existing role.", role.errors["title"]
  end
  
  def test_should_block_empty_role_title_on_edit
    role = Role.find @major_gods_role.id
    role.title = nil

    assert !role.save
    
    assert_equal 1, role.errors.count, 'Fails because of an error in RoR. See http://dev.rubyonrails.org/ticket/2022 for details.'
    assert_equal 'must have more than two characters.', role.errors['title']
  end
  
  def test_should_block_too_short_role_title_on_edit
    role = Role.find @major_gods_role.id
    role.title = '1'

    assert !role.save

    assert_equal 1, role.errors.count
    assert_equal 'must have more than two characters.', role.errors['title']
  end

  def test_should_block_too_long_role_title_on_edit
    role = Role.find @major_gods_role.id
    role.title = 'long ' * 100

    assert !role.save

    assert_equal 1, role.errors.count
    assert_equal 'must have less than 100 characters.', role.errors['title']
  end

  def test_should_block_invalid_characters_in_role_title_on_edit
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      role = Role.find @major_gods_role.id
      role.title = "invalid char: #{char}"

      assert !role.save

      assert_equal 1, role.errors.count
      assert_equal "must not contain invalid characters.", role.errors["title"]
    end
  end

  def test_should_block_non_unique_role_title_on_edit
    role = Role.find @gods_role.id
    role.title = @major_gods_role.title

    assert !role.save
    assert_equal 1, role.errors.count
    assert_equal "is the name of an already existing role.", role.errors["title"]
  end

  # No counterpart for edit since it can only happen with existing roles.
  def test_should_block_recursion_in_tree
    role = Role.find @gods_role.id
    
    assert_raises(RecursionInTree) { role.parent = Role.find @major_gods_role.id }
  end

  def test_should_block_destroy_role_with_children
    role = Role.find @gods_role.id
    assert_raises(CantDeleteWithChildren) { role.destroy }
  end

  def test_descendants_and_self_should_work_with_one_child
    role = Role.find @gods_role.id
    
    assert_equal 2, role.descendants_and_self.length
    assert_equal [@gods_role, @major_gods_role].sort {|a,b| a.id <=> b.id}, role.descendants_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_descendants_and_self_should_work_with_multiple_children_in_one_level
    child_role = Role.new
    child_role.title = 'Test Role #1'
    child_role.parent = @gods_role
    
    assert child_role.save
    
    role = Role.find @gods_role.id
    assert_equal 3, role.descendants_and_self.length
    assert_equal [@gods_role, @major_gods_role, child_role].sort {|a,b| a.id <=> b.id}, role.descendants_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_ancestors_and_self_should_work_with_no_ancestor
    role = Role.find @gods_role.id
    
    assert_equal 1, role.ancestors_and_self.length
    assert_equal [role].sort {|a,b| a.id <=> b.id}, role.ancestors_and_self.sort {|a,b| a.id <=> b.id}
  end

  def test_ancestors_and_self_should_work_with_one_ancestor
    role = Role.find @major_gods_role.id

    assert_equal 2, role.ancestors_and_self.length
    assert_equal [role, @gods_role].sort {|a,b| a.id <=> b.id}, role.ancestors_and_self.sort {|a,b| a.id <=> b.id}
  end
end