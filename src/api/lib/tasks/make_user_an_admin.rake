require 'tasks/user_admin_rights'

class MakeUserAnAdminTask
  # See https://supergood.software/dont-step-on-a-rake/
  include Rake::DSL

  attr_reader :user

  def initialize
    namespace(:user) do
      desc 'Give admin permissions to existing user'
      task toggle_admin_rights: :environment do
        login = ARGV[1]

        user = User.where(login: login).first

        UserAdminRights.new(user).toggle!

        admin_rights = user.admin? ? 'has' : 'does not have'

        puts "User '#{login}' #{admin_rights} admin rights from now on"

        exit
      rescue NotFoundError
        abort("User '#{login}' does not exist. Aborting.")
      end
    end
  end
end

# Instantiate the class to define the task
MakeUserAnAdminTask.new
