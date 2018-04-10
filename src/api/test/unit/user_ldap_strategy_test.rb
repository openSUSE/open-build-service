# frozen_string_literal: true

require_relative '../test_helper'

class UserLdapStrategyTest < ActiveSupport::TestCase
  def setup
    # Rails.logger = Logger.new(STDOUT)
  end

  def test_authenticate_with_local # spec/models/user_ldap_strategy_spec.rb
    a = UserLdapStrategy.authenticate_with_local('', {})
    assert a == false

    test_entry = {
      'userPassword'     => [],
      'CLR_userPassword' => ['test'],
      'MD5_userPassword' => ['{MD5}' + Base64.encode64(Digest::MD5.digest('test'))]
    }

    CONFIG['ldap_auth_mech'] = :foobar
    a = UserLdapStrategy.authenticate_with_local('', test_entry)
    assert a == false

    CONFIG['ldap_auth_mech'] = :cleartext
    a = UserLdapStrategy.authenticate_with_local('', test_entry)
    assert a == false
    a = UserLdapStrategy.authenticate_with_local('test', test_entry)
    assert a == false
    CONFIG['ldap_auth_attr'] = 'CLR_userPassword'
    a = UserLdapStrategy.authenticate_with_local('test', test_entry)
    assert a == true

    CONFIG['ldap_auth_mech'] = :md5
    CONFIG['ldap_auth_attr'] = 'MD5_userPassword'
    a = UserLdapStrategy.authenticate_with_local('', test_entry)
    assert a == false
    a = UserLdapStrategy.authenticate_with_local('test', test_entry)
    assert a == true
  end

  def test_dn2user_principal_name # spec/models/user_ldap_strategy_spec.rb
    a = UserLdapStrategy.dn2user_principal_name(['uid=jdoe', 'ou=People', 'dc=opensuse', 'dc=org'])
    assert a == 'jdoe@opensuse.org'

    a = UserLdapStrategy.dn2user_principal_name(['uid=jdoe,ou=People, dc=opensuse,dc=org'])
    assert a == 'jdoe@opensuse.org'

    a = UserLdapStrategy.dn2user_principal_name('uid=jdoe,ou=People, dc=opensuse,dc=org')
    assert a == 'jdoe@opensuse.org'

    a = UserLdapStrategy.dn2user_principal_name('uid=jdoe, dc=opensuse,dc=org')
    assert a == 'jdoe@opensuse.org'

    a = UserLdapStrategy.dn2user_principal_name(' dc=opensuse,dc=org')
    assert a.empty?

    a = UserLdapStrategy.dn2user_principal_name([' dc=opensuse,dc=org'])
    assert a.empty?
  end
end
