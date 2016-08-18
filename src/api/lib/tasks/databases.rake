module Rake
  module TaskManager
    def redefine_task(task_class, *args, &block)
      task_name, deps = resolve_args(args)
      task_name = task_class.scope_name(@scope, task_name)
      deps = [deps] unless deps.respond_to?(:to_ary)
      deps = deps.collect {|d| d.to_s }
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
    desc "Dump the database structure to a SQL file"
    task :dump => :environment do
      structure = ''
      abcs = ActiveRecord::Base.configurations
      case abcs[Rails.env]["adapter"]
      when "mysql2"
        ActiveRecord::Base.establish_connection(abcs[Rails.env])
        con = ActiveRecord::Base.connection

        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"

        structure = con.select_all(sql, 'SCHEMA').map { |table|
          table.delete('Table_type')
          sql = "SHOW CREATE TABLE #{con.quote_table_name(table.to_a.first.last)}"
          con.exec_query(sql, 'SCHEMA').first['Create Table'] + ";\n\n"
        }.join
      else
        raise "Task not supported by '#{abcs[Rails.env]["adapter"]}'"
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
      constraints = Array.new
      added_comma = false
      structure.each_line do |line|
        if line.match(%{[ ]*CONSTRAINT})
          unless line.end_with?(",\n")
            added_comma = true
            line = line[0..-2] + ",\n"
          end
          constraints << line
        else
          if constraints.count > 0
            constraints.sort!
            new_structure += constraints.join()
            if added_comma
              new_structure = new_structure[0..-3] + "\n"
            end
            constraints = Array.new
          end
          added_comma = false
          new_structure += line
        end
      end
      File.open("#{Rails.root}/db/structure.sql", "w+") { |f| f << new_structure }
    end
  end

  desc 'Create the database, load the structure, and initialize with the seed data'
  redefine_task :setup => :environment do
    Rake::Task["db:structure:load"].invoke
    Rake::Task["db:seed"].invoke
  end
end
