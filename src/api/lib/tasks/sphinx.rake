namespace :sphinx do
  desc 'Start the sphinx daemon'
  task start: :environment do
    if index_to_build?
      puts 'Index does not exist, creating it...'
      Rake::Task['ts:rebuild'].invoke
    else
      Rake::Task['ts:start'].invoke
    end
  end
end

def index_to_build?
  File.zero?("config/#{Rails.env}.sphinx.conf")
end
