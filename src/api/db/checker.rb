require 'colorize'

module DB
  class Checker
    attr_accessor :failed

    def self.run
      checker = new
      checker.warn_for_environment
      checker.resolve_devel_packages
      checker.check_foreign_keys
      checker.warn_for_rerun
    end

    def warn_for_environment
      return unless ENV['RAILS_ENV'] != 'production'
      puts "\nWARNING: This script is supposed to be running in \"production\" environment but actual is \"#{ENV['RAILS_ENV']}\".".red
      puts "         To do so just run \"RAILS_ENV=production ./script/check_database\"".red
    end

    def initialize
      @failed = false
    end

    def contraints_to_check
      # id, table, othertable, use_delete_statement
      [
        [:project_id, :packages, :projects, true],
        [:develpackage_id, :packages, :packages, false],
        [:repository_id, :repository_architectures, :repositories],
        [:architecture_id, :repository_architectures, :architectures],
        [:user_id, :watched_projects, :users],
        [:db_project_id, :db_projects_tags, :projects],
        [:tag_id, :db_projects_tags, :tags],
        [:attrib_type_id, :attribs, :attrib_types],
        [:package_id, :attribs, :packages],
        [:project_id, :attribs, :projects],
        [:project_id, :flags, :projects],
        [:package_id, :flags, :packages],
        [:architecture_id, :flags, :architectures],
        [:attrib_id, :attrib_values, :attribs],
        [:attrib_namespace_id, :attrib_types, :attrib_namespaces],
        [:group_id, :groups_roles, :groups],
        [:role_id, :groups_roles, :roles],
        [:group_id, :groups_users, :groups],
        [:user_id, :groups_users, :roles],
        [:package_id, :relationships, :packages],
        [:user_id, :relationships, :users],
        [:role_id, :relationships, :roles],
        [:project_id, :relationships, :projects],
        [:parent_id, :path_elements, :repositories],
        [:repository_id, :path_elements, :repositories],
        [:repository_id, :release_targets, :repositories],
        [:target_repository_id, :release_targets, :repositories],
        [:user_id, :ratings, :users],
        [:db_project_id, :repositories, :projects],
        [:parent_id, :roles, :roles],
        [:role_id, :roles_static_permissions, :roles],
        [:static_permission_id, :roles_static_permissions, :static_permissions],
        [:user_id, :roles_users, :users],
        [:role_id, :roles_users, :roles],
        [:tag_id, :taggings, :tags],
        [:user_id, :taggings, :users],
        [:user_id, :user_registrations, :users],
        [:attrib_type_id, :attrib_allowed_values, :attrib_types],
        [:attrib_type_id, :attrib_default_values, :attrib_types],
        [:attrib_namespace_id, :attrib_namespace_modifiable_bies, :attrib_namespaces],
        [:user_id, :attrib_namespace_modifiable_bies, :users],
        [:group_id, :attrib_namespace_modifiable_bies, :groups],
        [:package_id, :backend_packages, :packages],
        [:links_to_id, :backend_packages, :packages],
        [:parent_id, :comments, :comments],
        [:repository_id, :download_repositories, :repositories],
        [:project_id, :incident_updateinfo_counter_values, :projects]
      ]
    end

    def check_foreign_keys
      print "\nChecking constraints "
      constraints_to_fix = []
      contraints_to_check.each do |constraint|
        ids = check_foreign_key(constraint)
        print step(ids.empty? ? :ok : :fail)
        constraints_to_fix << [constraint, ids] unless ids.empty?
      end
      puts summary(constraints_to_fix.empty? ? :ok : :fail)
      puts "\n  Trying to fix inconsistent records in #{constraints_to_fix.size} constraints:".yellow if constraints_to_fix.any?
      constraints_to_fix.each do |constraint_and_ids|
        ask_for_fixing(*constraint_and_ids)
      end
    end

    def resolve_devel_packages
      print "\nChecking devel packages "
      begin
        User.current = User.find_by_login('_nobody_')
        projects = {}
        Package.where("develpackage_id is not null").each do |package|
          begin
            package.resolve_devel_package
            print step(:ok)
          rescue Package::CycleError => e
            projects[package.project.name] ||= []
            projects[package.project.name] << [package.name, e.message]
            print step(:fail)
          end
        end
        puts summary(projects.empty? ? :ok : :fail)
        projects.keys.sort.each do |project|
          puts "\n  Errors detected at project #{"\"#{project}\"".blue}:\n"
          projects[project].each do |package_name_and_message|
            puts "    #{package_name_and_message.first.blue}: #{package_name_and_message.last.red}"
          end
        end
      rescue StandardError => e
        puts summary(:fail)
        puts e.message.red
      end
    end

    def warn_for_rerun
      if failed
        puts "\nWARNING: You should run this check again to be sure that all problems were fixed\n".red
      else
        puts "\nAll checks passed\n".green
      end
    end

    private

    def check_foreign_key(constraint)
      id, table, othertable = *constraint
      sql = "select distinct #{id} from #{table} where #{id} is not null and #{id} not in (select id from #{othertable});"
      execute_sql(sql).map(&:first)
    end

    def ask_for_fixing(constraint, ids)
      id, table, othertable, use_delete_statement = *constraint
      use_delete_statement ||= true
      puts "\n  Inconsistent FOREIGN KEY for #{"\"#{table}.#{id}\"".blue} that references #{"\"#{othertable}.id\"".blue}"
      if use_delete_statement
        statement = "delete from #{table} where #{id} in (#{ids.join(',')});"
      else
        statement = "update #{table} set #{id}=NULL where #{id} in (#{ids.join(',')});"
      end
      print "  Proposed solution: #{statement.green} Do you want to run it now? #{'[y/N]'.yellow}:"
      execute_sql(statement) if gets.chomp.casecmp('Y').zero?
    end

    def execute_sql(sql)
      ActiveRecord::Base.connection.execute(sql)
    end

    def step(ok = :ok)
      if ok.to_sym == :ok
        '.'.green
      else
        'x'.red
      end
    end

    def summary(ok = :ok)
      if ok.to_sym == :ok
        "[#{'OK'.green}]"
      else
        @failed = true
        "[#{'FAIL'.red}]"
      end
    end
  end
end
