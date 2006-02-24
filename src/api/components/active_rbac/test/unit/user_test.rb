require File.dirname(__FILE__) + '/../test_helper'

# TODO: Test timestamps

class UserTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions
  
  def setup
  end
  
  def create_valid_new_user
    user = User.new
    user.login = 'New User'
    user.email = 'user@localhost'
    user.password = 'fine_password'
    user.password_confirmation = 'fine_password'
    
    user.groups << @greek_heroes_group << @cretes_group
    user.roles << @gods_role << @greek_kings_role
    
    return user
  end

  #
  # The tests
  # 
  def test_users_from_fixtures_should_have_correct_properties
    fixture_users = [ @agamemnon_user, @ariadne_user, @daidalos_user,
                      @dionysus_user, @hades_user, @hephaestus_user,
                      @hermes_user, @icarus_user, @medusa_user,
                      @minos_user, @odysseus_user, @perseus_user,
                      @zeus_user ]
    
    for fixture_user in fixture_users do
      queried_user = User.find fixture_user.id

      assert_equal queried_user.id, fixture_user.id
      assert_equal queried_user.created_at, fixture_user.created_at
      assert_equal queried_user.updated_at, fixture_user.updated_at
      assert_equal queried_user.login, fixture_user.login
      assert_equal queried_user.email, fixture_user.email
      assert_equal queried_user.password, fixture_user.password
      assert_equal queried_user.password_hash_type, fixture_user.password_hash_type
      assert_equal queried_user.state, fixture_user.state
    end
  end

  def test_users_from_fixtures_should_have_correct_groups
    agamemnon = User.find @agamemnon_user.id
    assert_equal 1, agamemnon.groups.length
    assert_equal [@troys_besiegers_group].sort {|a,b| a.id <=> b.id}, agamemnon.groups.sort {|a,b| a.id <=> b.id}

    ariadne = User.find @ariadne_user.id
    assert_equal 1, ariadne.groups.length
    assert_equal [@cretes_group].sort {|a,b| a.id <=> b.id}, ariadne.groups.sort {|a,b| a.id <=> b.id}
    
    hades = User.find @hades_user.id
    assert_equal 1, hades.groups.length
    assert_equal [@gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, hades.groups.sort {|a,b| a.id <=> b.id}
    
    minos = User.find @minos_user.id
    assert_equal 1, minos.groups.length
    assert_equal [@greek_kings_group].sort {|a,b| a.id <=> b.id}, minos.groups.sort {|a,b| a.id <=> b.id}

    odysseus = User.find @odysseus_user.id
    assert_equal 1, odysseus.groups.length
    assert_equal [@punished_heroes_group].sort {|a,b| a.id <=> b.id}, odysseus.groups.sort {|a,b| a.id <=> b.id}

    perseus = User.find @perseus_user.id
    assert_equal 1, perseus.groups.length
    assert_equal [@greek_heroes_group].sort {|a,b| a.id <=> b.id}, perseus.groups.sort {|a,b| a.id <=> b.id}

    no_group_users = [ @daidalos_user, @dionysus_user, @hephaestus_user,
                       @hermes_user, @icarus_user, @medusa_user, @zeus_user ]
                       
    no_group_users.each do |u|
      user = User.find u.id
      assert_equal 0, user.groups.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_users_from_fixtures_should_have_correct_all_groups
    agamemnon = User.find @agamemnon_user.id
    assert_equal 2, agamemnon.all_groups.length
    assert_equal [@troys_besiegers_group, @greek_warriors_group].sort {|a,b| a.id <=> b.id}, agamemnon.all_groups.sort {|a,b| a.id <=> b.id}

    ariadne = User.find @ariadne_user.id
    assert_equal 2, ariadne.all_groups.length
    assert_equal [@cretes_group, @greeks_group].sort {|a,b| a.id <=> b.id}, ariadne.all_groups.sort {|a,b| a.id <=> b.id}

    hades = User.find @hades_user.id
    assert_equal 2, hades.all_groups.length
    assert_equal [@gods_not_in_olymp_group, @gods_group].sort {|a,b| a.id <=> b.id}, hades.all_groups.sort {|a,b| a.id <=> b.id}

    minos = User.find @minos_user.id
    assert_equal 2, minos.all_groups.length
    assert_equal [@greek_kings_group, @greeks_group].sort {|a,b| a.id <=> b.id}, minos.all_groups.sort {|a,b| a.id <=> b.id}

    odysseus = User.find @odysseus_user.id
    assert_equal 1, odysseus.all_groups.length
    assert_equal [@punished_heroes_group].sort {|a,b| a.id <=> b.id}, odysseus.all_groups.sort {|a,b| a.id <=> b.id}

    perseus = User.find @perseus_user.id
    assert_equal 1, perseus.all_groups.length
    assert_equal [@greek_heroes_group].sort {|a,b| a.id <=> b.id}, perseus.all_groups.sort {|a,b| a.id <=> b.id}

    no_all_group_users = [ @daidalos_user, @dionysus_user, @hephaestus_user,
                           @hermes_user, @icarus_user, @medusa_user, @zeus_user ]

    no_all_group_users.each do |u|
      user = User.find u.id
      assert_equal 0, user.all_groups.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, user.all_groups.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_users_from_fixtures_should_have_correct_roles
    hermes = User.find @hermes_user.id
    assert_equal 1, hermes.roles.length
    assert_equal [@gods_role].sort {|a,b| a.id <=> b.id}, hermes.roles.sort {|a,b| a.id <=> b.id}

    zeus = User.find @zeus_user.id
    assert_equal 1, zeus.roles.length
    assert_equal [@major_gods_role].sort {|a,b| a.id <=> b.id}, zeus.roles.sort {|a,b| a.id <=> b.id}

    no_roles_users = [ @agamemnon_user, @ariadne_user, @daidalos_user,
                       @dionysus_user, @hades_user, @hephaestus_user,
                       @icarus_user, @medusa_user, @minos_user, 
                       @odysseus_user, @perseus_user ]

    no_roles_users.each do |u|
      user = User.find u.id
      assert_equal 0, user.roles.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_users_from_fixtures_should_have_correct_all_roles
    agamemnon = User.find @agamemnon_user.id
    assert_equal 2, agamemnon.all_roles.length
    assert_equal [@greek_warriors_role, @greeks_role].sort {|a,b| a.id <=> b.id}, agamemnon.all_roles.sort {|a,b| a.id <=> b.id}

    hermes = User.find @hermes_user.id
    assert_equal 1, hermes.all_roles.length
    assert_equal [@gods_role].sort {|a,b| a.id <=> b.id}, hermes.all_roles.sort {|a,b| a.id <=> b.id}

    hades = User.find @hades_user.id
    assert_equal 1, hades.all_roles.length
    assert_equal [@god_of_death_role].sort {|a,b| a.id <=> b.id}, hades.all_roles.sort {|a,b| a.id <=> b.id}

    minos = User.find @minos_user.id
    assert_equal 2, minos.all_roles.length
    assert_equal [@greek_kings_role, @greek_men_role].sort {|a,b| a.id <=> b.id}, minos.all_roles.sort {|a,b| a.id <=> b.id}

    perseus = User.find @perseus_user.id
    assert_equal 1, perseus.all_roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, perseus.all_roles.sort {|a,b| a.id <=> b.id}

    zeus = User.find @zeus_user.id
    assert_equal 2, zeus.all_roles.length
    assert_equal [@major_gods_role, @gods_role].sort {|a,b| a.id <=> b.id}, zeus.all_roles.sort {|a,b| a.id <=> b.id}

    no_all_roles_users = [ @ariadne_user, @daidalos_user,
                           @dionysus_user, @hephaestus_user,
                           @icarus_user, @medusa_user,
                           @odysseus_user ]

    no_all_roles_users.each do |u|
      user = User.find u.id
      assert_equal 0, user.all_roles.length
      assert_equal [].sort {|a,b| a.id <=> b.id}, user.all_roles.sort {|a,b| a.id <=> b.id}
    end
  end

  def test_add_with_valid_data_should_work
    user = self.create_valid_new_user
    
    assert user.save
    user.reload
    
    assert_equal 'New User', user.login
    assert_equal 'user@localhost', user.email
    assert_equal Digest::MD5.hexdigest('fine_password' + user.password_salt), user.password
    assert_equal 2, user.groups.length
    assert_equal [@greek_heroes_group, @cretes_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
    assert_equal 2, user.roles.length
    assert_equal [@gods_role, @greek_kings_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
    
    assert_equal User.states['unconfirmed'], user.state
    
    # a bit esoterical maybe
    assert_in_delta Time.new.to_i, user.created_at.to_i, 10
    assert_in_delta Time.new.to_i, user.updated_at.to_i, 10
    assert_in_delta Time.new.to_i, user.last_logged_in_at.to_i, 10
  end
  
  def test_edit_existing_with_valid_data_should_work
    user = User.find @agamemnon_user.id
    
    user.login = 'New Login'
    user.email = 'email@nowhere.com'
    user.password = 'my password'
    user.password_confirmation = 'my password'
    user.groups.delete @troys_besiegers_group

    assert user.save
    user.reload
    
    assert_equal 'New Login', user.login
    assert_equal 'email@nowhere.com', user.email
    assert_equal Digest::MD5.hexdigest('my password' + user.password_salt), user.password
    assert_equal 0, user.groups.length
    assert_equal [].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
    assert_equal 0, user.roles.length
    assert_equal [].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_destroy_should_work
    User.destroy @agamemnon_user.id
    assert_raise(ActiveRecord::RecordNotFound) { User.find @agamemnon_user.id }
  end
  
  def test_destroy_should_remove_all_role_assignments
    User.destroy @zeus_user.id
    role = Role.find @major_gods_role.id
    assert_equal 0, role.users.length
    assert_equal [].sort {|a,b| a.id <=> b.id}, role.users.sort {|a,b| a.id <=> b.id}
  end

  def test_destroy_should_remove_all_group_assignments
    User.destroy @agamemnon_user.id
    group = Group.find @troys_besiegers_group.id
    assert_equal 0, group.users.length
    assert_equal [].sort {|a,b| a.id <=> b.id}, group.users.sort {|a,b| a.id <=> b.id}
  end
  
  def test_assinging_one_role_should_work
    user = User.find @ariadne_user.id
    user.roles << @greek_kings_role

    assert user.save
    user.reload
    
    assert_equal 1, user.roles.length
    assert_equal [@greek_kings_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_assigning_multiple_roles_should_work
    user = User.find @ariadne_user.id
    user.roles << @greek_kings_role << @greek_heroes_role

    assert user.save
    user.reload

    assert_equal 2, user.roles.length
    assert_equal [@greek_heroes_role, @greek_kings_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_deassigning_one_role_should_work
    # add roles
    user = User.find @ariadne_user.id
    user.roles << @greek_kings_role << @greek_heroes_role
    assert user.save
    user.reload

    assert_equal 2, user.roles.length
    assert_equal [@greek_kings_role, @greek_heroes_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
    
    # remove them again
    user = User.find @ariadne_user.id
    user.roles.delete @greek_kings_role
    user.save
    user.reload

    assert_equal 1, user.roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_deassigning_multiple_roles_should_work
    # add roles
    user = User.find @ariadne_user.id
    user.roles << @greek_kings_role << @greek_heroes_role << @god_of_death_role

    assert user.save
    user.reload

    assert_equal 3, user.roles.length
    assert_equal [@greek_kings_role, @greek_heroes_role, @god_of_death_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}

    # remove them again
    user = User.find @ariadne_user.id
    user.roles.delete @greek_kings_role
    user.roles.delete @god_of_death_role
    
    assert user.save
    user.reload

    assert_equal 1, user.roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, user.roles.sort {|a,b| a.id <=> b.id}
  end

  def test_assigning_one_group_should_work
    user = User.find @icarus_user.id
    user.groups << @greek_heroes_group

    assert user.save
    user.reload

    assert_equal 1, user.groups.length
    assert_equal [@greek_heroes_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
  end

  def test_assinging_multiple_groups_should_work
    user = User.find @icarus_user.id
    user.groups << @greek_heroes_group << @gods_not_in_olymp_group

    assert user.save
    user.reload

    assert_equal 2, user.groups.length
    assert_equal [@greek_heroes_group, @gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
  end

  def test_deassigning_one_group_should_work
    # add the roles
    user = User.find @icarus_user.id
    user.groups << @greek_heroes_group << @gods_not_in_olymp_group

    assert user.save
    user.reload

    assert_equal 2, user.groups.length
    assert_equal [@greek_heroes_group, @gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
    
    # and remove them again
    user.groups.delete @greek_heroes_group

    assert user.save
    user.reload

    assert_equal 1, user.groups.length
    assert_equal [@gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
  end

  def test_deassinging_multiple_groups_should_work
    # add the roles
    user = User.find @icarus_user.id
    user.groups << @greek_heroes_group << @gods_not_in_olymp_group << @greek_warriors_group

    assert user.save
    user.reload

    assert_equal 3, user.groups.length
    assert_equal [@greek_heroes_group, @gods_not_in_olymp_group, @greek_warriors_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}

    # and remove them again
    user.groups.delete @greek_heroes_group
    user.groups.delete @greek_warriors_group

    assert user.save
    user.reload

    assert_equal 1, user.groups.length
    assert_equal [@gods_not_in_olymp_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
  end

  def test_should_be_granted_one_role_by_his_groups
    # icarus has no roles, so he is a good dummy
    user = User.find @icarus_user.id
    user.groups << @greek_heroes_group << @punished_heroes_group
    
    assert user.save
    user.reload

    assert_equal 2, user.groups.length
    assert_equal [@greek_heroes_group, @punished_heroes_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
    
    assert_equal 1, user.all_roles.length
    assert_equal [@greek_heroes_role].sort {|a,b| a.id <=> b.id}, user.all_roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_should_be_granted_multiple_roles_by_his_groups
    # icarus has no roles, so he is a good dummy
    user = User.find @icarus_user.id
    user.groups << @greek_kings_group << @punished_heroes_group << @troys_besiegers_group

    assert user.save
    user.reload

    assert_equal 3, user.groups.length
    assert_equal [@greek_kings_group, @punished_heroes_group, @troys_besiegers_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}

    assert_equal 4, user.all_roles.length
    assert_equal [@greek_kings_role, @greek_men_role, @greek_warriors_role, @greeks_role].sort {|a,b| a.id <=> b.id}, user.all_roles.sort {|a,b| a.id <=> b.id}
  end
  
  def test_should_ignore_duplicate_role_assignment
    # NOTE: This is broken but seemingly because of a bug in RoR
    # See http://dev.rubyonrails.org/ticket/2019 for details
    
    # icarus has no roles, so he is a good dummy
    user = User.find @icarus_user.id
    user.groups << @greek_kings_group << @punished_heroes_group << @troys_besiegers_group
    user.roles << @greek_warriors_role << @greek_warriors_role

    assert user.save
    user.reload

    assert_equal 3, user.groups.length
    assert_equal [@greek_kings_group, @punished_heroes_group, @troys_besiegers_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}

    assert_equal 4, user.all_roles.length
    assert_equal [@greek_warriors_role, @greeks_role, @greek_kings_role, @greek_men_role].sort {|a,b| a.id <=> b.id}, user.all_roles.sort {|a,b| a.id <=> b.id}
  end

  def test_should_ignore_duplicate_group_assignment
    # NOTE: This is broken but seemingly because of a bug in RoR
    # See http://dev.rubyonrails.org/ticket/2019 for details

    # icarus has no roles, so he is a good dummy
    user = User.find @icarus_user.id
    user.groups << @greek_kings_group << @greek_kings_group

    assert user.save
    user.reload

    assert_equal 1, user.groups.length
    assert_equal [@greek_kings_group].sort {|a,b| a.id <=> b.id}, user.groups.sort {|a,b| a.id <=> b.id}
  end
  
  def test_should_block_creation_with_too_short_login
    user = self.create_valid_new_user
    user.login = '1'
    
    assert !user.save
    
    assert_equal 1, user.errors.count
    assert_equal "must have more than two characters.", user.errors["login"]
  end
  
  def test_should_block_creation_with_too_long_login
    user = self.create_valid_new_user
    user.login = 'long' * 100

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal "must have less than 100 characters.", user.errors["login"]
  end
  
  def test_should_block_creation_with_login_with_invalid_characters
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]
    
    for char in invalid_chars do
      user = self.create_valid_new_user
      user.login = "invalid char #{char}"

      assert !user.save

      assert_equal 1, user.errors.count
      assert_equal "must not contain invalid characters.", user.errors["login"]
    end
  end
  
  def test_should_block_creation_with_invalid_email_address
    user = self.create_valid_new_user
    user.email = 'invalid address'

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal "must be a valid email address.", user.errors["email"]
  end

  def test_should_block_creation_with_too_long_password
    user = self.create_valid_new_user
    user.update_password('long' * 100)

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must have between 6 and 64 characters.', user.errors["password"]
  end

  def test_should_block_creation_with_too_short_password
    user = self.create_valid_new_user
    user.update_password('short')

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must have between 6 and 64 characters.', user.errors["password"]
  end

  def test_should_block_creation_with_invalid_characters_in_password
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      user = self.create_valid_new_user
      user.update_password "invalid char #{char}"

      assert !user.save
      
      assert_equal 1, user.errors.count
      assert_equal 'must not contain invalid characters.', user.errors["password"]
    end
  end
  
  def test_should_encrypt_password_on_creation_after_save
    user = self.create_valid_new_user

    assert user.save
    user.reload

    assert user.password_equals?('fine_password') 
  end
  
  def test_login_should_work
    assert_equal @icarus_user, User.find_with_credentials('Icarus', 'password')
  end

  def test_login_should_fail_with_invalid_login
    assert_nil User.find_with_credentials('Icarus123', 'password')
  end

  def test_login_should_fail_with_invalid_password
    assert_nil User.find_with_credentials('Icarus', 'password123')
  end

  def test_login_failures_should_be_increased_on_wrong_login
    assert_equal 0, User.find(@icarus_user.id).login_failure_count
    assert_nil User.find_with_credentials('Icarus', 'password123')
    assert_equal 1, User.find(@icarus_user.id).login_failure_count
  end
  
  def test_login_failures_should_be_reset_on_correct_login
    # login failure
    assert_nil User.find_with_credentials('Icarus', 'password123')

    # login success
    assert_kind_of User, User.find_with_credentials('Icarus', 'password')
    assert_equal 0, User.find(@icarus_user.id).login_failure_count
  end

  def test_should_block_editing_with_too_short_login
    user = User.find @icarus_user.id
    user.login = '1'

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal "must have more than two characters.", user.errors["login"]
  end

  def test_should_block_editing_with_too_long_login
    user = User.find @icarus_user.id
    user.login = 'long' * 100

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal "must have less than 100 characters.", user.errors["login"]
  end

  def test_should_block_editing_with_login_with_invalid_characters
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      user = User.find @icarus_user.id
      user.login = "invalid char #{char}"

      assert !user.save

      assert_equal 1, user.errors.count
      assert_equal "must not contain invalid characters.", user.errors["login"]
    end
  end

  def test_should_block_editing_with_invalid_email_address
    user = User.find @icarus_user.id
    user.email = 'invalid address'

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal "must be a valid email address.", user.errors["email"]
  end

  def test_should_block_editing_with_too_long_password
    user = User.find @icarus_user.id
    user.update_password('long' * 100)

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must have between 6 and 64 characters.', user.errors["password"]
  end

  def test_should_block_editing_with_too_short_password
    user = User.find @icarus_user.id
    user.update_password('short')

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must have between 6 and 64 characters.', user.errors["password"]
  end

  def test_should_block_editing_with_invalid_characters_in_password
    invalid_chars = [ '%', '§', '†', '∆', '¥', '≈', 'ç', '∂', 'ƒ', '©', 'ª', 'º', '∆', '«' ]

    for char in invalid_chars do
      user = User.find @icarus_user.id
      user.update_password "invalid char #{char}"

      assert !user.save

      assert_equal 1, user.errors.count
      assert_equal 'must not contain invalid characters.', user.errors["password"]
    end
  end

  def test_should_block_editing_with_invalid_state
    user = User.find @icarus_user.id
    user.state = 12345

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must be in the list of states.', user.errors["state"]
  end

  def test_should_block_editing_with_wrong_password_hash_type
    user = User.find @icarus_user.id
    user.update_password 'new password'
    user.password_hash_type = 'INVALID HASH TYPE MWHAHAHAH'

    assert !user.save

    assert_equal 1, user.errors.count
    assert_equal 'must be in the list of hash types.', user.errors["password_hash_type"]
  end

  def test_should_encrypt_password_on_editing_after_save
    user = User.find @icarus_user.id
    user.update_password 'My Fine New Password'

    assert user.save
    user.reload

    assert user.password_equals?('My Fine New Password')
  end

  def test_should_set_update_timestamp_on_editing
    user = User.find @icarus_user.id

    old_time = user.updated_at

    assert user.save

    assert((old_time.to_i - user.updated_at.to_i) < 0)
    assert_in_delta Time.now.to_i, user.updated_at.to_i, (60)
  end

  def test_should_not_set_creation_timestamp_on_editing
    user = User.find @icarus_user.id

    old_time = user.created_at

    assert user.save

    assert(old_time.to_i - user.created_at.to_i == 0)
  end

  def test_should_allow_editing_state_with_valid_transitions
    User.states.each_value do |state|
      user = User.find @icarus_user.id
      
      next unless user.state_transition_allowed?(user.state, state) or (user.state == state)
      
      user.state = state

      assert user.save
      assert_equal 0, user.errors.count

      user.reload
      assert_equal state, user.state
    end
  end
  
  def test_should_block_editing_states_with_invalid_transitions
    User.states.each_value do |state|
      user = User.find @icarus_user.id
      
      next if user.state_transition_allowed?(user.state, state) or (user.state == state)
      
      user.state = state

      assert !user.save
      assert_equal 1, user.errors.count
      assert !user.errors[:state].nil?
    end
  end
  
  def test_should_allow_editing_login_with_valid_value
    user = User.find @icarus_user.id
    user.login = 'Not Icarus'

    assert user.save
    user.reload

    assert_equal 'Not Icarus', user.login
  end

  def test_should_allow_editing_email_with_valid_value
    user = User.find @icarus_user.id
    user.email = 'root@localhost'

    assert user.save
    user.reload

    assert_equal 'root@localhost', user.email
  end

  def test_should_allow_editing_password_with_valid_value
    user = User.find @icarus_user.id
    user.password = 'fine new password'
    user.password_confirmation = 'fine new password'

    assert user.save
    user.reload

    assert user.password_equals?('fine new password')
  end

  def test_should_allow_editing_password_hash_type_with_valid_value_and_password_change
    user = User.find @icarus_user.id
    user.password = 'fine new password'
    user.password_confirmation = 'fine new password'
    user.password_hash_type = 'md5'

    assert user.save
    assert_equal 0, user.errors.count
  end

  def test_should_block_password_hash_type_change_without_password_change
    user = User.find @icarus_user.id
    user.password_hash_type = 'md5'

    assert !user.save
    assert_equal 1, user.errors.count
    assert_equal 'cannot be changed unless a new password has been provided.', user.errors["password_hash_type"]
    assert user.password_equals?('password')
  end
  
  def test_should_not_change_timestamps_on_valid_login
    # Don't change updated_at timestamp on valid logins
    user = User.find @icarus_user.id
    old_time = user.updated_at
    
    user = User.find_with_credentials('Icarus', 'password')
    user.did_log_in
    new_time = user.updated_at
    
    assert_equal old_time.to_i, new_time.to_i
  end

  def test_should_not_change_timestamps_on_invalid_login
    # Don't change updated_at timestamp on invalid logins
    user = User.find @icarus_user.id
    old_time = user.updated_at

    user = User.find_with_credentials('Icarus', 'wrong password')

    user = User.find @icarus_user.id
    new_time = user.updated_at

    assert_equal old_time.to_i, new_time.to_i
    
    # and now reset the login_failure_count on the valid login
    self.test_should_not_change_timestamps_on_valid_login
  end

  def test_purge_expired_users_should_work
    assert_equal 13, User.count
    User.purge_users_with_expired_registration
    assert_equal 12, User.count
    assert_raises(ActiveRecord::RecordNotFound) { User.find @dionysus_user.id }
  end

  def test_return_false_on_has_role_if_correct
    # user with no role
    user = User.find @icarus_user.id
    assert !user.has_role(@greek_heroes_role.title)
    
    # user with another role
    user = User.find @agamemnon_user.id
    assert !user.has_role(@greek_heroes_role.title)
  end
  
  def test_return_true_on_has_role_if_correct
    user = User.find @perseus_user.id
    assert user.has_role(@greek_heroes_role.title)
  end

  def test_return_false_on_has_permission_if_correct
    # user with no permission
    user = User.find @icarus_user.id
    assert !user.has_permission(@access_olymp_permission.title)
    
    # user with another permission
    user = User.find @agamemnon_user.id
    assert !user.has_permission(@access_olymp_permission.title)
  end
  
  def test_return_true_on_has_permission_if_correct
    user = User.find @zeus_user.id
    assert user.has_permission(@access_olymp_permission.title)
  end
end
