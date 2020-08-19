namespace :sphinx do
  desc 'Start the sphinx daemon'
  task start: :environment do
    if index_to_build?
      puts 'Index does not exist, creating it...'
      Rake::Task['ts:rt:rebuild'].invoke
    else
      Rake::Task['ts:start'].invoke
    end
  end

  desc 'Start the sphinx daemon for the development environment'
  task start_for_development: :environment do
    if index_to_build?
      Rake::Task['ts:rt:clear'].invoke
      Rake::Task['ts:configure'].invoke
      t = Thread.new do
        retries = 0
        sphinx_is_running = false
        while !sphinx_is_running && retries < 10
          sleep(5)
          sphinx_is_running = `rails ts:status`.chomp == 'The Sphinx daemon searchd is currently running.'
          retries += 1
        end
        Rake::Task['ts:rt:index'].invoke if sphinx_is_running
      end
      sh('rails ts:start NODETACH=true')
      t.join
    else
      exec('rails ts:start NODETACH=true')
    end
  end
end

def index_to_build?
  filename = "config/#{Rails.env}.sphinx.conf"
  !File.file?(filename) || File.zero?(filename)
end
