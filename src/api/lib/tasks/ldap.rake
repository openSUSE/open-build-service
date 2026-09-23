#!/usr/bin/env ruby

namespace :ldap do
  task test_connection: :environment do
    Rails.logger = Logger.new($stdout)
    puts UserLdapStrategy.send(:initialize_ldap_con, CONFIG['ldap_search_user'], CONFIG['ldap_search_auth']).inspect
    puts UserLdapStrategy.find_with_ldap('admin', 'opensuse').inspect
  end
end
