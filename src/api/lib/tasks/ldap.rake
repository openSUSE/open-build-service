#!/usr/bin/env ruby

namespace :ldap do
  task test_connection: :environment do
    CONFIG['ldap_servers'] = 'ldap'
    CONFIG['ldap_ssl'] = :off
    CONFIG['ldap_search_base'] = 'dc=example,dc=org'

    Rails.logger = Logger.new(STDOUT)
    puts UserLdapStrategy.initialize_ldap_con('cn=admin,dc=example,dc=org', 'opensuse').inspect
  end
end
