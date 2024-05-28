#!/usr/bin/env ruby

namespace :ldap do
  task test_connection: :environment do
    puts UserLdapStrategy.initialize_ldap_con('Admin', 'opensuse').inspect
  end
end
