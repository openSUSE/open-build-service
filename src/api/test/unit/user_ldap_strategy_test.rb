require_relative '../test_helper'

class UserLdapStrategyTest < ActiveSupport::TestCase
  def setup
    # Rails.logger = Logger.new(STDOUT)
  end

  # spec/models/user_ldap_strategy_spec.rb
  def test_dn2user_principal_name
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
