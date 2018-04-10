# frozen_string_literal: true
namespace :user do
  desc 'Give admin permissions to existing user'
  task give_admin_rights: :environment do
    login = ARGV[1]

    user = User.where(login: login).first
    if user
      if user.roles.where(title: 'Admin').exists?
        puts "Nothing to do here. User '#{user.login}' already is an admin."
      else
        puts "Making user '#{login}' an admin"
        user.roles << Role.global.where(title: 'Admin').first
      end
    else
      puts "Couldn't find user '#{login}'"
    end

    exit
  end
end
