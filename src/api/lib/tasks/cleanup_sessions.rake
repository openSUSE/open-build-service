namespace :db do
  desc 'Deletes sessions not running - run often'
  task cleanup_sessions: :environment do
    abcs = ActiveRecord::Base.configurations
    case abcs[Rails.env]['adapter']
    when 'mysql2'
      ActiveRecord::Base.establish_connection(abcs[Rails.env])
      ActiveRecord::Base.connection.execute('DELETE FROM sessions WHERE updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY)')
    else
      raise "Task not supported by '#{abcs[Rails.env]['adapter']}'"
    end
  end
end
