namespace :db do
  desc "Deletes sessions not running - run often"
  task :cleanup_sessions => :environment do
      abcs = ActiveRecord::Base.configurations
      case abcs[RAILS_ENV]["adapter"]
      when "mysql"
        ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
        ActiveRecord::Base.connection.execute 'DELETE FROM sessions WHERE updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY)'
      else
        raise "Task not supported by '#{abcs[RAILS_ENV]["adapter"]}'"
      end
  end
end

