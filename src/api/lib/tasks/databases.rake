# frozen_string_literal: true
module Rake
  module TaskManager
    def redefine_task(task_class, *args, &block)
      task_name, deps = resolve_args(args)
      task_name = task_class.scope_name(@scope, task_name)
      deps = [deps] unless deps.respond_to?(:to_ary)
      deps = deps.collect(&:to_s)
      task = @tasks[task_name.to_s] = task_class.new(task_name, self)
      task.application = self
      # task.add_comment(@last_comment)
      @last_comment = nil
      task.enhance(deps, &block)
      task
    end
  end
  class Task
    class << self
      def redefine_task(args, &block)
        Rake.application.redefine_task(self, args, &block)
      end
    end
  end
end

def redefine_task(args, &block)
  Rake::Task.redefine_task(args, &block)
end

namespace :db do
  namespace :structure do
    desc 'Dump the database structure to a SQL file'
    task dump: :environment do
      structure = ''
      abcs = ActiveRecord::Base.configurations
      case abcs[Rails.env]['adapter']
      when 'mysql2'
        ActiveRecord::Base.establish_connection(abcs[Rails.env])
        con = ActiveRecord::Base.connection

        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"

        structure = con.select_all(sql, 'SCHEMA').map do |table|
          table.delete('Table_type')
          sql = "SHOW CREATE TABLE #{con.quote_table_name(table.to_a.first.last)}"
          con.exec_query(sql, 'SCHEMA').first['Create Table'] + ";\n\n"
        end.join
      else
        raise "Task not supported by '#{abcs[Rails.env]['adapter']}'"
      end

      if ActiveRecord::Base.connection.supports_migrations?
        structure << ActiveRecord::Base.connection.dump_schema_information
      end

      structure.gsub!(%r{AUTO_INCREMENT=[0-9]* }, '')
      structure.gsub!('auto_increment', 'AUTO_INCREMENT')
      structure.gsub!(%r{default([, ])}, 'DEFAULT\1')
      structure.gsub!(%r{KEY  *}, 'KEY ')
      structure += "\n"
      # sort the constraint lines always in the same order
      new_structure = ''
      constraints = []
      added_comma = false
      structure.each_line do |line|
        if line =~ /[ ]*CONSTRAINT/
          unless line.end_with?(",\n")
            added_comma = true
            line = line[0..-2] + ",\n"
          end
          constraints << line
        else
          if constraints.count > 0
            constraints.sort!
            new_structure += constraints.join
            new_structure = new_structure[0..-3] + "\n" if added_comma
            constraints = []
          end
          added_comma = false
          new_structure += line
        end
      end
      File.open("#{Rails.root}/db/structure.sql", 'w+') { |f| f << new_structure }
    end

    desc 'Verify that structure.sql in git is up to date'
    task verify: :environment do
      puts 'Running rails db:migrate'
      Rake::Task['db:migrate'].invoke
      puts 'Diffing the db/structure.sql'
      sh %(git diff --quiet db/structure.sql) do |ok, _|
        unless ok
          abort 'Generated structure.sql differs from structure.sql stored in git. ' \
                'Please run rake db:migrate and check the differences.'
        end
      end
      puts 'Everything looks fine!'
    end

    desc 'Verify that structure.sql does not use any columns with type = bigint'
    task verify_no_bigint: :environment do
      puts 'Checking db/structure.sql for bigint'

      bigint_lines = %x(grep "bigint" #{Rails.root}/db/structure.sql)

      if bigint_lines.present?
        abort <<-STR
          Please do not use bigint column type in db/structure.sql.
          You may need to call create_table with `id: :integer` to avoid the id column using bigint.
        STR
      end

      puts 'Ok'
    end
  end

  desc 'Create the database, load the structure, and initialize with the seed data'
  redefine_task setup: :environment do
    Rake::Task['db:structure:load'].invoke
    Rake::Task['db:seed'].invoke
  end

  desc 'Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)'
  task migrate: :environment do
    puts ''
    puts 'warning: db:migrate only migrates your database structure, not the data contained in it.'
    puts 'warning for migrating your data run data:migrate'
    puts ''
  end
end
